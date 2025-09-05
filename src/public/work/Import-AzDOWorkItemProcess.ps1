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

System fields (those with names starting with 'System.') are excluded from export
and import as they are pre-defined in Azure DevOps. All other fields, including
custom fields, will be processed.

Custom fields will be namespaced with the process name:
- Original field: MyField
- Imported field: ProcessName.MyField

This allows tracking which process created the field and enables safe overwrites
when re-importing the same process. Use -Force to overwrite existing fields
without confirmation.
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
        $failedFields = @()
        $importedFields = @()

        $progress = @{
            Activity = "Importing process from '$Path'"
        }

        Write-Progress @progress -Status 'Reading process definition...'
        $processDefinition = Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop

        $requiredFields = ('name', 'typeId', 'workItemTypes')

        foreach ($field in $requiredFields) {
            if (-not $processDefinition.$field) {
                throw "Invalid process definition file. Missing required field '$field'."
            }
        }

        # Ensure work item types have the minimum required properties for import
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
            # Process-level fields must be created before work item types can reference them
            if ($processDefinition.fields) {
                $fieldCount = $processDefinition.fields.Count
                foreach ($field in $processDefinition.fields) {
                    $fieldIndex = $processDefinition.fields.IndexOf($field) + 1
                    $progress['Status'] = "Importing process fields ($fieldIndex of $fieldCount)..."
                    $progress['CurrentOperation'] = $field.name
                    $progress['PercentComplete'] = ($fieldIndex / $fieldCount) * 100
                    Write-Progress @progress

                    try {
                        $fieldToImport = $field.PSObject.Copy()
                        if ($fieldToImport.referenceName -notlike "*$($processDefinition.name).*") {
                            $fieldToImport.referenceName = "$($processDefinition.name).$($fieldToImport.referenceName)"
                        }

                        Invoke-AzDORestApiMethod `
                            @script:AzApiHeaders `
                            -Method Post `
                            -Endpoint 'wit/fields' `
                            -Body ($fieldToImport | ConvertTo-Json -Compress) `
                            -NoRetry:$NoRetry -ErrorAction Stop

                        $importedFields += [PSCustomObject]@{
                            Name          = $field.name
                            ReferenceName = $fieldToImport.referenceName
                            Type          = $field.type
                            Action        = 'Created'
                        }
                    }
                    catch {
                        # Silently continue if field exists - common during re-imports
                        Write-Verbose "Field $($fieldToImport.referenceName) may already exist: $_"
                    }
                }
            }

            # Behaviors may be referenced by work item type configurations
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
                        if ($existingProcess) {
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
                            # Azure DevOps requires states to be created in workflow order
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
                                    $msg = "Could not create state '$($state.name)' for '$witName'."
                                    $msg += " It may already exist: $_"
                                    Write-Warning $msg
                                }
                            }
                        }

                        if ($wit.fields) {
                            Write-Progress @progress -CurrentOperation 'Fields'
                            foreach ($field in $wit.fields) {
                                try {
                                    # Custom fields require organization-level creation before assignment
                                    if ($field.referenceName -notlike 'System.*') {
                                        $fieldToCreate = $field.PSObject.Copy()

                                        # Namespace prevents conflicts with existing custom fields
                                        $processPrefix = "$($processDefinition.name)."
                                        if ($fieldToCreate.referenceName -notlike "*$processPrefix*") {
                                            $newName = "$processPrefix$($fieldToCreate.referenceName)"
                                            $fieldToCreate.referenceName = $newName
                                        }

                                        # These properties are determined by field usage, not definition
                                        $createField = $fieldToCreate | Select-Object -Property * -ExcludeProperty `
                                            isRequired, isLocked, isIdentity

                                        try {
                                            Invoke-AzDORestApiMethod `
                                                @script:AzApiHeaders `
                                                -Method Post `
                                                -Endpoint 'wit/fields' `
                                                -Body ($createField | ConvertTo-Json -Compress) `
                                                -NoRetry:$NoRetry -ErrorAction Stop

                                            $importedFields += [PSCustomObject]@{
                                                Name          = $field.name
                                                ReferenceName = $fieldToCreate.referenceName
                                                Type          = $field.type
                                                Action        = 'Created'
                                            }
                                        }
                                        catch {
                                            Write-Verbose "Field $($fieldToCreate.referenceName) may already exist: $_"
                                        }

                                        $field.referenceName = $fieldToCreate.referenceName
                                    }

                                    Invoke-AzDORestApiMethod `
                                        @script:AzApiHeaders `
                                        -Method Post `
                                        -Endpoint "work/processes/$processId/workitemtypes/$witName/fields" `
                                        -Body ($field | ConvertTo-Json -Compress) `
                                        -NoRetry:$NoRetry -ErrorAction Stop
                                }
                                catch {
                                    $msg = "Could not add field '$($field.name)' to type '$witName': $_"
                                    Write-Warning $msg
                                    $failedFields += [PSCustomObject]@{
                                        Name          = $field.name
                                        ReferenceName = $field.referenceName
                                        Type          = $field.type
                                        Error         = $_.Exception.Message
                                    }
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

                        # Test work item types have locked layouts that cannot be modified
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

            Write-Host "`nImport Summary:" -ForegroundColor Cyan

            if ($importedFields.Count -gt 0) {
                Write-Host "`nSuccessfully imported fields:" -ForegroundColor Green
                $importedFields | ForEach-Object {
                    Write-Host "- $($_.Name) ($($_.ReferenceName)) - $($_.Action)"
                }
                Write-Host @"
`nTo remove these fields if needed:
1. Navigate to Organization Settings > Process > Fields
2. Search for each field by its reference name
3. Select the field and click Delete
   Note: Fields that are in use cannot be deleted until all usages are removed
"@ -ForegroundColor Yellow
            }

            if ($failedFields.Count -gt 0) {
                Write-Warning @"
`nThe following fields could not be imported and may need manual configuration:
$($failedFields | ForEach-Object {
    "- $($_.Name) ($($_.ReferenceName)): $($_.Error)"
} | Out-String)
To manually configure these fields:
1. Navigate to Organization Settings > Process > Fields
2. Verify if the fields already exist and check their configurations
3. Create or update fields as needed
"@
            }

            $result
        }
    }
}
