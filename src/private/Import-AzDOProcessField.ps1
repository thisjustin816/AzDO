<#
.SYNOPSIS
Imports a single process field into Azure DevOps.

.DESCRIPTION
This private helper function handles the logic for creating or updating a single work item field
within a process. It ensures the field is correctly namespaced with the process name to avoid
conflicts and support portability.

The function attempts to create the field via a POST request. If the creation fails and the
-Force switch is specified, it assumes the field may already exist and does not attempt an
update, as the fields API does not support PUT for updates.

.PARAMETER Field
The PSObject representing the field to be imported.

.PARAMETER ProcessName
The name of the process to which the field belongs. Used for namespacing the field's
reference name.

.PARAMETER ApiHeaders
The pre-initialized hashtable of API headers required for making REST calls.

.PARAMETER Force
If specified, suppresses errors if the field already exists.

.PARAMETER NoRetry
A switch to disable the default retry mechanism for REST API calls.

.EXAMPLE
Import-AzDOProcessField -Field $field -ProcessName "MyProcess" -ApiHeaders $headers -Force
This example imports the specified $field into the "MyProcess" process.

.NOTES
This is a private helper function and is not intended for direct use. It is dot-sourced by
the Import-AzDOWorkItemProcess function.
#>
function Import-AzDOProcessField {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Field,
        [Parameter(Mandatory = $true)]
        [String]$ProcessName,
        [Parameter(Mandatory = $true)]
        [Hashtable]$ApiHeaders,
        [Switch]$Force,
        [Switch]$AutoResolveConflicts,
        [Switch]$NoRetry
    )

    try {
        $fieldToImport = $Field.PSObject.Copy()
        if ($fieldToImport.referenceName -notlike "*$ProcessName.*") {
            $fieldToImport.referenceName = "$ProcessName.$($fieldToImport.referenceName)"
        }

        $propsToRemove = @('id', 'url', '_links', 'usage')
        foreach ($prop in $propsToRemove) {
            if ($fieldToImport.PSObject.Properties[$prop]) {
                $fieldToImport.PSObject.Properties.Remove($prop)
            }
        }

        if (-not $fieldToImport.friendlyName -and $fieldToImport.name) {
            $fieldToImport | Add-Member -MemberType NoteProperty -Name 'friendlyName' -Value $fieldToImport.name -Force
        }

        $fieldErrorAction = if ($Force) { 'Stop' } else { 'SilentlyContinue' }
        Invoke-AzDORestApiMethod @ApiHeaders `
            -Method Post `
            -Endpoint 'wit/fields' `
            -Body ($fieldToImport | ConvertTo-Json -Compress) `
            -NoRetry:$NoRetry -ErrorAction $fieldErrorAction

        return [PSCustomObject]@{
            Success       = $true
            Name          = $Field.name
            ReferenceName = $fieldToImport.referenceName
            Type          = $Field.type
            Action        = if ($Force) { 'Created/Updated' } else { 'Created' }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        $isSystemField   = $Field.referenceName -like 'System.*'
        $isStandardField = $Field.referenceName -like 'Microsoft.VSTS.*'
        $isCustomField   = $Field.referenceName -like 'Custom.*'

        if ($AutoResolveConflicts) {
            # VS402803: name conflict (already in use)
            if ($errorMessage -like '*VS402803*already in use*') {
                if ($isSystemField -or $isStandardField) {
                    return [PSCustomObject]@{
                        Success       = $true
                        Name          = $Field.name
                        ReferenceName = $Field.referenceName
                        Type          = $Field.type
                        Action        = 'Used Existing Standard Field'
                    }
                }
                # Custom field: fall through to existing custom field creation logic below
            }
            # 404: not found (field exists at runtime but not visible during import)
            elseif ($errorMessage -like '*404*not found*') {
                if ($isSystemField -or $isStandardField) {
                    return [PSCustomObject]@{
                        Success       = $true
                        Name          = $Field.name
                        ReferenceName = $Field.referenceName
                        Type          = $Field.type
                        Action        = 'Available at Runtime'
                    }
                }
            }
            # Any other error for standard fields: skip creation
            elseif ($isSystemField -or $isStandardField) {
                return [PSCustomObject]@{
                    Success       = $true
                    Name          = $Field.name
                    ReferenceName = $Field.referenceName
                    Type          = $Field.type
                    Action        = 'Skipped - Standard Field'
                }
            }
            # Custom field creation logic (unchanged)
            if ($isCustomField) {
                $processName = $ProcessName -replace '\s', ''
                $newFieldName = "$processName.$($Field.name)"
                $newReferenceName = "$processName.$($Field.referenceName)"

                $customFieldToCreate = $Field.PSObject.Copy()
                $customFieldToCreate.name = $newFieldName
                $customFieldToCreate.referenceName = $newReferenceName

                @('id', 'url', '_links', 'usage') | ForEach-Object {
                    if ($customFieldToCreate.PSObject.Properties[$_]) {
                        $customFieldToCreate.PSObject.Properties.Remove($_)
                    }
                }

                if (-not $customFieldToCreate.friendlyName -and $customFieldToCreate.name) {
                    $customFieldToCreate | Add-Member `
                        -MemberType NoteProperty `
                        -Name 'friendlyName' `
                        -Value $customFieldToCreate.name `
                        -Force
                }

                try {
                    Write-Information "Creating custom field '$newFieldName'" -InformationAction Continue
                    Invoke-AzDORestApiMethod @ApiHeaders `
                        -Method Post `
                        -Endpoint 'wit/fields' `
                        -Body ($customFieldToCreate | ConvertTo-Json -Compress) `
                        -NoRetry:$NoRetry

                    return [PSCustomObject]@{
                        Success       = $true
                        Name          = $customFieldToCreate.name
                        ReferenceName = $customFieldToCreate.referenceName
                        Type          = $Field.type
                        Action        = 'Created Custom Field'
                    }
                }
                catch {
                    Write-Warning "Failed to create custom field '$($Field.name)': $_"
                    return [PSCustomObject]@{
                        Success       = $false
                        Name          = $Field.name
                        ReferenceName = $Field.referenceName
                        Type          = $Field.type
                        Error         = $_.Exception.Message
                        Action        = 'Custom Field Creation Failed'
                    }
                }
            }
        }

        if ($Force) {
            Write-Warning "Could not create/update field '$($fieldToImport.referenceName)': $_"
        }
        else {
            Write-Verbose "Field $($fieldToImport.referenceName) may already exist: $_"
        }
        return [PSCustomObject]@{
            Success       = $false
            Name          = $Field.name
            ReferenceName = $Field.referenceName
            Type          = $Field.type
            Error         = $_.Exception.Message
            Action        = 'Failed'
        }
    }
}
