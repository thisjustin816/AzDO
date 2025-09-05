<#
.SYNOPSIS
Imports a work item process definition from a JSON file.

.DESCRIPTION
Imports a work item process definition from a JSON file. This can be used to restore process backups
or import processes from another organization.

.PARAMETER Path
The path to the JSON file containing the process definition.

.PARAMETER Pat
Personal access token with Process (manage) permissions. Defaults to $env:SYSTEM_ACCESSTOKEN.

.PARAMETER CollectionUri
The collection URI of the Azure DevOps organization. Defaults to $env:SYSTEM_COLLECTIONURI.

.PARAMETER Force
If specified, will overwrite an existing process with the same name.

.EXAMPLE
Import-AzDOWorkItemProcess -Path "C:\Temp\Agile.json"

.NOTES
This function requires Process (manage) permissions in the organization.
#>
function Import-AzDOWorkItemProcess {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path,
        [Switch]$Force,
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1'
        }
    }

    process {
        $progress = @{
            Activity = "Importing process from '$Path'"
        }

        Write-Progress @progress -Status 'Reading process definition...'
        $processDefinition = Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop

        # Validate required process fields
        $requiredFields = ('name', 'typeId', 'workItemTypes')

        foreach ($field in $requiredFields) {
            if (-not $processDefinition.$field) {
                throw "Invalid process definition file. Missing required field '$field'."
            }
        }

        # Validate work item types have required fields
        if ($processDefinition.workItemTypes) {
            foreach ($wit in $processDefinition.workItemTypes) {
                if (-not $wit.referenceName) {
                    throw "Invalid work item type definition. Missing required field 'referenceName'."
                }
            }
        }

        Write-Progress @progress -Status 'Checking for existing process...'
        $existingProcess = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint 'work/processes' `
            -NoRetry:$NoRetry |
            Where-Object { $_.name -eq $processDefinition.name }

        $result = $null
        $restParams = @{
            Body    = (
                $processDefinition |
                    Select-Object -Property name, description, parentProcessTypeId |
                    ConvertTo-Json -Compress
            )
            NoRetry = $NoRetry
        }

        if ($existingProcess) {
            $operation = "Update process '$($processDefinition.name)'"
            if ($Force -or $PSCmdlet.ShouldProcess($processDefinition.name, $operation)) {
                Write-Progress @progress -Status 'Updating process information...'
                $result = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    @restParams `
                    -Method Put `
                    -Endpoint "work/processes/$($existingProcess.typeId)"
                $processId = $existingProcess.typeId
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess($processDefinition.name, 'Create process')) {
                Write-Progress @progress -Status 'Creating new process...'
                $result = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    @restParams `
                    -Method Post `
                    -Endpoint 'work/processes'
                $processId = $result.typeId
            }
        }

        if ($result) {
            if ($processDefinition.fields) {
                $fieldCount = $processDefinition.fields.Count
                foreach ($field in $processDefinition.fields) {
                    $fieldIndex = $processDefinition.fields.IndexOf($field) + 1
                    $progress['Status'] = "Importing process fields ($fieldIndex of $fieldCount)..."
                    $progress['CurrentOperation'] = $field.name
                    $progress['PercentComplete'] = ($fieldIndex / $fieldCount) * 100
                    Write-Progress @progress
                    try {
                        Invoke-AzDORestApiMethod `
                            @script:AzApiHeaders `
                            -Method Post `
                            -Endpoint "wit/fields" `
                            -Body ( $field | ConvertTo-Json -Compress ) `
                            -NoRetry:$NoRetry -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Warning "Could not create field '$($field.name)'. It may already exist: $_"
                    }
                }
            }

            # Import process behaviors
            if ($processDefinition.behaviors) {
                $behaviorCount = $processDefinition.behaviors.Count
                foreach ($behavior in $processDefinition.behaviors) {
                    $behaviorIndex = $processDefinition.behaviors.IndexOf($behavior) + 1
                    $progress['Status'] = "Importing process behaviors ($behaviorIndex of $behaviorCount)..."
                    $progress['CurrentOperation'] = $behavior.name
                    $progress['PercentComplete'] = ($behaviorIndex / $behaviorCount) * 100
                    Write-Progress @progress
                    try {
                        Invoke-AzDORestApiMethod `
                            @script:AzApiHeaders `
                            -Method Post `
                            -Endpoint "work/processes/$processId/behaviors" `
                            -Body ( $behavior | ConvertTo-Json -Compress ) `
                            -NoRetry:$NoRetry -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Warning "Could not create behavior '$($behavior.name)'. It may already exist: $_"
                    }
                }
            }

            # Import work item types and their components
            if ($processDefinition.workItemTypes) {
                $witTotal = $processDefinition.workItemTypes.Count
                foreach ($wit in $processDefinition.workItemTypes) {
                    $witName = $wit.referenceName
                    $witIndex = $processDefinition.workItemTypes.IndexOf($wit) + 1
                    $progress['Status'] = "Processing work item type: $witName ($witIndex of $witTotal)..."
                    $progress['PercentComplete'] = ($witIndex / $witTotal) * 100
                    Write-Progress @progress

                    try {
                        $witResult = if ($existingProcess) {
                            $body = $wit |
                                Select-Object -Property color, description, icon, isDisabled, name |
                                ConvertTo-Json -Compress
                            Invoke-AzDORestApiMethod `
                                @script:AzApiHeaders `
                                -Method Put `
                                -Endpoint "work/processes/$processId/workitemtypes/$witName" `
                                -Body $body `
                                -NoRetry:$NoRetry
                        }
                        else {
                            $body = $wit |
                                Select-Object -Property color, description, icon, isDisabled, name, referenceName |
                                ConvertTo-Json -Compress
                            Invoke-AzDORestApiMethod `
                                @script:AzApiHeaders `
                                -Method Post `
                                -Endpoint "work/processes/$processId/workitemtypes" `
                                -Body $body `
                                -NoRetry:$NoRetry
                        }

                        if ($wit.states) {
                            Write-Progress @progress -CurrentOperation 'States'
                            # States must be created in order by their state category
                            $orderedStates = $wit.states | Sort-Object -Property @{
                                Expression = {
                                    switch ($_.stateCategory) {
                                        'Proposed' { 1 }
                                        'InProgress' { 2 }
                                        'Resolved' { 3 }
                                        'Completed' { 4 }
                                        'Removed' { 5 }
                                        default { 99 }
                                    }
                                }
                            }
                            foreach ($state in $orderedStates) {
                                try {
                                    Invoke-AzDORestApiMethod `
                                        @script:AzApiHeaders `
                                        -Method Post `
                                        -Endpoint "work/processes/$processId/workitemtypes/$witName/states" `
                                        -Body ( $state | ConvertTo-Json -Compress ) `
                                        -NoRetry:$NoRetry -ErrorAction SilentlyContinue
                                }
                                catch {
                                    Write-Warning "Could not create state '$($state.name)' for '$witName'. It may already exist: $_"
                                }
                            }
                        }

                        if ($wit.fields) {
                            Write-Progress @progress -CurrentOperation 'Fields'
                            foreach ($field in $wit.fields) {
                                try {
                                    Invoke-AzDORestApiMethod `
                                        @script:AzApiHeaders `
                                        -Method Post `
                                        -Endpoint "work/processes/$processId/workitemtypes/$witName/fields" `
                                        -Body ($field | ConvertTo-Json -Compress) `
                                        -NoRetry:$NoRetry -ErrorAction SilentlyContinue
                                }
                                catch {
                                    Write-Warning "Could not create field '$($field.name)' for '$witName'. It may already exist: $_"
                                }
                            }
                        }

                        if ($wit.rules) {
                            Write-Progress @progress -CurrentOperation 'Rules'
                            foreach ($rule in $wit.rules) {
                                try {
                                    Invoke-AzDORestApiMethod `
                                        @script:AzApiHeaders `
                                        -Method Post `
                                        -Endpoint "work/processes/$processId/workitemtypes/$witName/rules" `
                                        -Body ($rule | ConvertTo-Json -Compress) `
                                        -NoRetry:$NoRetry -ErrorAction SilentlyContinue
                                }
                                catch {
                                    Write-Warning "Could not create rule for '$witName'. It may already exist: $_"
                                }
                            }
                        }

                        # Only update layout for non-Test work item types as Test types are locked
                        if ($wit.layout -and -not $witName.StartsWith('Microsoft.VSTS.WorkItemTypes.Test')) {
                            Write-Progress @progress -CurrentOperation 'Layout'
                            try {
                                Invoke-AzDORestApiMethod `
                                    @script:AzApiHeaders `
                                    -Method Put `
                                    -Endpoint "work/processes/$processId/workitemtypes/$witName/layout" `
                                    -Body ($wit.layout | ConvertTo-Json -Depth 100 -Compress) `
                                    -NoRetry:$NoRetry
                            }
                            catch {
                                Write-Warning "Could not update layout for '$witName': $_"
                            }
                        }
                    }
                    catch {
                        Write-Warning "Could not create/update work item type '$witName': $_"
                    }
                }
            }

            Write-Progress @progress -Completed
            $result
        }
    }
}
