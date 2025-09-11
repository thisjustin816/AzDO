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
If specified, will overwrite existing process components (fields, behaviors, states, rules, layouts)
without confirmation. Without this flag, existing components are skipped.

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
when re-importing the same process. Use -Force to overwrite existing process
components (fields, behaviors, states, rules, layouts) without confirmation.
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
        . "$PSScriptRoot\..\..\private\Clear-AzDOObjectOrgData.ps1"
        . "$PSScriptRoot\..\..\private\Import-AzDOProcessField.ps1"
        . "$PSScriptRoot\..\..\private\Import-AzDOBehavior.ps1"

        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1'
        }

        # Organization-specific properties to remove from behavior objects
        $script:OrgSpecificProps = @('inherits', 'url', '_links', 'id', 'customization', 'referenceName', 'rank')
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
            Write-Progress @progress -Status "Using existing process '$($existingProcess.name)'"
            $processId = $existingProcess.typeId
            $result = $existingProcess
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

        if (-not $processId) {
            throw (
                'Process creation or lookup failed. Unable to proceed with import. ' +
                'Ensure the process exists or creation was not skipped.'
            )
        }

        # Process-level fields must be created before work item types can reference them
        if ($processDefinition.fields) {
            $fieldCount = $processDefinition.fields.Count
            foreach ($field in $processDefinition.fields) {
                $fieldIndex = $processDefinition.fields.IndexOf($field) + 1
                $progress['Status'] = "Importing process fields ($fieldIndex of $fieldCount)..."
                $progress['CurrentOperation'] = $field.name
                $progress['PercentComplete'] = ($fieldIndex / $fieldCount) * 100
                Write-Progress @progress

                $importResult = Import-AzDOProcessField `
                    -Field $field `
                    -ProcessName $processDefinition.name `
                    -ApiHeaders $script:AzApiHeaders `
                    -Force:$Force `
                    -NoRetry:$NoRetry

                if ($importResult.Success) {
                    $importedFields += $importResult
                }
            }
        }

        # Behaviors may be referenced by work item type configurations
        if ($processDefinition.behaviors) {
            $failedBehaviors = @()
            $skippedBehaviors = @()
            $behaviorCount = $processDefinition.behaviors.Count
            $systemBehaviors = $processDefinition.behaviors | Where-Object { $_.referenceName -like 'System.*' }
            $customBehaviors = $processDefinition.behaviors | Where-Object { $_.referenceName -notlike 'System.*' }

            # Process system behaviors first - these should already exist and just need assignment
            foreach ($behavior in $systemBehaviors) {
                $behaviorIndex = $processDefinition.behaviors.IndexOf($behavior) + 1
                $progress['Status'] = "Assigning system behavior ($behaviorIndex of $behaviorCount): $($behavior.name)"
                $progress['CurrentOperation'] = $behavior.name
                $progress['PercentComplete'] = ($behaviorIndex / $behaviorCount) * 100
                Write-Progress @progress

                Write-Verbose "Skipping creation of system behavior '$($behavior.name)' - should already exist"
            }

            # Process custom behaviors
            foreach ($behavior in $customBehaviors) {
                $behaviorIndex = $processDefinition.behaviors.IndexOf($behavior) + 1
                $progress['Status'] = "Importing custom behavior ($behaviorIndex of $behaviorCount): $($behavior.name)"
                $progress['CurrentOperation'] = $behavior.name
                $progress['PercentComplete'] = ($behaviorIndex / $behaviorCount) * 100
                Write-Progress @progress

                $importResult = Import-AzDOBehavior `
                    -Behavior $behavior `
                    -ProcessId $processId `
                    -ApiHeaders $script:AzApiHeaders `
                    -PropertiesToRemove $script:OrgSpecificProps `
                    -Force:$Force `
                    -NoRetry:$NoRetry

                if (-not $importResult.Success) {
                    $failedBehaviors += $importResult
                }
                elseif ($importResult.Skipped) {
                    $skippedBehaviors += $importResult
                }
            }
        }

        if ($processDefinition.workItemTypes) {
            $witTotal = $processDefinition.workItemTypes.Count
            foreach ($wit in $processDefinition.workItemTypes) {
                $witName = $wit.referenceName
                $witIndex = $processDefinition.workItemTypes.IndexOf($wit) + 1
                $progress['Status'] = "Processing work item type: $witName ($witIndex of $witTotal)..."
                $progress['PercentComplete'] = ($witIndex / $witTotal) * 100
                Write-Progress @progress

                # Skip system work item types - cannot be imported
                if ($witName.StartsWith('Microsoft.VSTS.WorkItemTypes.') -or $witName.StartsWith('System.')) {
                    Write-Verbose "Skipping system work item type: $witName"
                    continue
                }

                # Create custom work item type
                try {
                    $body = $wit |
                        Select-Object -Property color, description, icon, isDisabled, name, referenceName |
                        ConvertTo-Json -Compress

                    try {
                        Invoke-AzDORestApiMethod `
                            @script:AzApiHeaders `
                            -Method Post `
                            -Endpoint "work/processes/$processId/workitemtypes" `
                            -Body $body `
                            -NoRetry:$NoRetry `
                            -ErrorAction Stop
                    }
                    catch {
                        if ($Force) {
                            try {
                                $updateBody = $wit |
                                    Select-Object -Property color, description, icon, isDisabled, name |
                                    ConvertTo-Json -Compress
                                Invoke-AzDORestApiMethod `
                                    @script:AzApiHeaders `
                                    -Method Put `
                                    -Endpoint "work/processes/$processId/workitemtypes/$witName" `
                                    -Body $updateBody `
                                    -NoRetry:$NoRetry -ErrorAction Stop
                            }
                            catch {
                                Write-Warning "Could not create or update work item type '$witName': $_"
                            }
                        }
                        else {
                            Write-Verbose "Work item type '$witName' may already exist: $_"
                        }
                    }
                }
                catch {
                    Write-Warning "Could not create/update work item type '$witName': $_"
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
                            $stateErrorAction = if ($Force) { 'Stop' } else { 'SilentlyContinue' }
                            Invoke-AzDORestApiMethod `
                                @script:AzApiHeaders `
                                -Method Post `
                                -Endpoint "work/processes/$processId/workitemtypes/$witName/states" `
                                -Body ( $state | ConvertTo-Json -Compress ) `
                                -NoRetry:$NoRetry -ErrorAction $stateErrorAction
                        }
                        catch {
                            $msg = "Could not create state '$($state.name)' for '$witName'."
                            if ($Force) {
                                $msg += " Error: $_"
                                Write-Warning $msg
                            }
                            else {
                                $msg += " It may already exist: $_"
                                Write-Warning $msg
                            }
                        }
                    }
                }

                if ($wit.fields) {
                    Write-Progress @progress -CurrentOperation 'Fields'
                    foreach ($field in $wit.fields) {
                        try {
                            if ($field.referenceName -notlike 'System.*') {
                                $fieldToCreate = $field.PSObject.Copy()

                                $processPrefix = "$($processDefinition.name)."
                                if ($fieldToCreate.referenceName -notlike "*$processPrefix*") {
                                    $newName = "$processPrefix$($fieldToCreate.referenceName)"
                                    $fieldToCreate.referenceName = $newName
                                }

                                $createField = $fieldToCreate | Select-Object -Property * -ExcludeProperty `
                                    isRequired, isLocked, isIdentity

                                try {
                                    $witFieldErrorAction = if ($Force) { 'Stop' } else { 'SilentlyContinue' }
                                    Invoke-AzDORestApiMethod `
                                        @script:AzApiHeaders `
                                        -Method Post `
                                        -Endpoint 'wit/fields' `
                                        -Body ($createField | ConvertTo-Json -Compress) `
                                        -NoRetry:$NoRetry -ErrorAction $witFieldErrorAction

                                    $importedFields += [PSCustomObject]@{
                                        Name          = $field.name
                                        ReferenceName = $fieldToCreate.referenceName
                                        Type          = $field.type
                                        Action        = if ($Force) { 'Created/Updated' } else { 'Created' }
                                    }
                                }
                                catch {
                                    if ($Force) {
                                        Write-Warning (
                                            "Field $($fieldToCreate.referenceName) could not be " +
                                            "created/updated: $_"
                                        )
                                    }
                                    else {
                                        Write-Verbose (
                                            "Field $($fieldToCreate.referenceName) may already " +
                                            "exist: $_"
                                        )
                                    }
                                }

                                $field.referenceName = $fieldToCreate.referenceName
                            }

                            $fieldAssignErrorAction = if ($Force) { 'Stop' } else { 'SilentlyContinue' }
                            Invoke-AzDORestApiMethod `
                                @script:AzApiHeaders `
                                -Method Post `
                                -Endpoint "work/processes/$processId/workitemtypes/$witName/fields" `
                                -Body ($field | ConvertTo-Json -Compress) `
                                -NoRetry:$NoRetry -ErrorAction $fieldAssignErrorAction
                        }
                        catch {
                            if ($Force) {
                                $errorMessage = $_.Exception.Message
                                $isFieldNotFound = $errorMessage -like "*TF400016*" -or
                                                  $errorMessage -like "*field does not exist*"
                                $isFieldNameConflict = $errorMessage -like "*TF400014*" -or
                                                      $errorMessage -like "*name conflict*"
                                $isSystemFieldRestriction = $errorMessage -like "*TF400013*" -or
                                                           $errorMessage -like "*system field*"

                                $category = if ($isFieldNotFound) { "Field Reference Not Found" }
                                           elseif ($isFieldNameConflict) { "Field Name Conflict" }
                                           elseif ($isSystemFieldRestriction) { "System Field Restriction" }
                                           else { "Other Error" }

                                $failedFields += [PSCustomObject]@{
                                    Name          = $field.name
                                    ReferenceName = $field.referenceName
                                    Type          = $field.type
                                    Error         = $errorMessage
                                    Category      = $category
                                }
                            }
                            else {
                                Write-Verbose "Field '$($field.name)' may already be assigned to '$witName': $_"
                            }
                        }
                    }
                }

                if ($wit.rules) {
                    Write-Progress @progress -CurrentOperation 'Rules'
                    foreach ($rule in $wit.rules) {
                        try {
                            $ruleErrorAction = if ($Force) { 'Stop' } else { 'SilentlyContinue' }
                            Invoke-AzDORestApiMethod `
                                @script:AzApiHeaders `
                                -Method Post `
                                -Endpoint "work/processes/$processId/workitemtypes/$witName/rules" `
                                -Body ($rule | ConvertTo-Json -Compress) `
                                -NoRetry:$NoRetry -ErrorAction $ruleErrorAction
                        }
                        catch {
                            if ($Force) {
                                Write-Warning "Could not create/update rule for '$witName': $_"
                            }
                            else {
                                Write-Warning "Could not create rule for '$witName'. It may already exist: $_"
                            }
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
                        if ($Force) {
                            Write-Warning "Could not update layout for '$witName': $_"
                        }
                        else {
                            Write-Verbose (
                                "Could not update layout for '$witName' " +
                                "(use -Force to see errors): $_"
                            )
                        }
                    }
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
            # Group errors by category for organized reporting
            $errorsByCategory = $failedFields | Group-Object -Property Category

            Write-Warning "`nField import errors by category:"
            foreach ($category in $errorsByCategory) {
                $count = $category.Count
                $categoryName = $category.Name
                Write-Host "`n$categoryName ($count fields):" -ForegroundColor Red

                $category.Group | ForEach-Object {
                    Write-Host "  - $($_.Name) ($($_.ReferenceName))" -ForegroundColor Gray
                }
            }

            Write-Host @"

Field Error Resolution Guide:
• Field Reference Not Found: Field may not exist in target organization
  → Navigate to Organization Settings > Process > Fields to create missing fields
• Field Name Conflict: Field with same name but different properties exists
  → Check existing field configuration and resolve naming conflicts
• System Field Restriction: Cannot modify system-defined fields
  → System fields are managed by Azure DevOps and cannot be customized
• Other Error: Various API or permission issues
  → Check error details and ensure proper permissions

To manually configure failed fields:
1. Navigate to Organization Settings > Process > Fields
2. Verify if the fields already exist and check their configurations
3. Create or update fields as needed matching the process requirements
"@ -ForegroundColor Yellow
        }

        if ($failedBehaviors.Count -gt 0) {
            Write-Warning @"
`nThe following behaviors could not be imported and may need manual configuration:
$($failedBehaviors | ForEach-Object {
    "- $($_.Name) ($($_.ReferenceName)): $($_.Error)"
} | Out-String)
Common causes and solutions:
1. Organization-specific GUIDs or references in behavior definitions
2. Dependencies on other behaviors not yet imported
3. Process template restrictions

To manually configure these behaviors:
1. Navigate to Organization Settings > Process > $($processDefinition.name) > Behaviors
2. Create new behaviors with the names listed above
3. Configure behavior properties based on the original process definition
4. Re-run the import with -Force to continue with other components
"@
        }

        # Report skipped system types
        $skippedTypes = $processDefinition.workItemTypes | Where-Object {
            $_.referenceName.StartsWith('Microsoft.VSTS.WorkItemTypes.') -or $_.referenceName.StartsWith('System.')
        }
        if ($skippedTypes) {
            Write-Host "`nSkipped system work item types (cannot be imported):" -ForegroundColor Yellow
            $skippedTypes | ForEach-Object {
                Write-Host "- $($_.name) ($($_.referenceName))"
            }
        }

        # Report skipped behaviors
        if ($skippedBehaviors -and $skippedBehaviors.Count -gt 0) {
            Write-Host "`nSkipped organization-specific behaviors:" -ForegroundColor Yellow
            $skippedBehaviors | ForEach-Object {
                Write-Host "- $($_.Name) ($($_.ReferenceName)) - $($_.Reason)"
            }
        }

        $result
    }
}
