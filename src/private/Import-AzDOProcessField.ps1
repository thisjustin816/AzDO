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
        # Ensure field reference name includes process namespace for portability
        if ($fieldToImport.referenceName -notlike "*$ProcessName.*") {
            $fieldToImport.referenceName = "$ProcessName.$($fieldToImport.referenceName)"
        }

        # Remove organization-specific properties that can cause API errors
        $propsToRemove = @('id', 'url', '_links', 'usage')
        foreach ($prop in $propsToRemove) {
            if ($fieldToImport.PSObject.Properties[$prop]) {
                $fieldToImport.PSObject.Properties.Remove($prop)
            }
        }

        # Ensure friendlyName exists (some APIs expect this)
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
        if ($AutoResolveConflicts -and $errorMessage -like "*name*conflict*") {
            $isStandardField = $Field.referenceName -like "Microsoft.VSTS.*" -or $Field.referenceName -like "System.*"
            if ($isStandardField) {
                Write-Information "Standard field '$($Field.name)' exists - using existing" -InformationAction Continue
                return [PSCustomObject]@{
                    Success       = $true
                    Name          = $Field.name
                    ReferenceName = $Field.referenceName
                    Type          = $Field.type
                    Action        = 'Used Existing Standard Field'
                }
            }

            # Custom field - rename with process prefix
            $processName = $ProcessName -replace '\s', ''
            $fieldToImport.name = "$processName.$($Field.name)"

            # Update friendlyName to match the new name
            if ($fieldToImport.friendlyName) {
                $fieldToImport.friendlyName = $fieldToImport.name
            }

            try {
                Invoke-AzDORestApiMethod @ApiHeaders `
                    -Method Post `
                    -Endpoint 'wit/fields' `
                    -Body ($fieldToImport | ConvertTo-Json -Compress) `
                    -NoRetry:$NoRetry

                return [PSCustomObject]@{
                    Success       = $true
                    Name          = $fieldToImport.name
                    ReferenceName = $fieldToImport.referenceName
                    Type          = $Field.type
                    Action        = 'Created with Process Prefix'
                }
            }
            catch {
                Write-Warning "Auto-resolution failed for field '$($Field.name)': $_"
                return [PSCustomObject]@{
                    Success       = $false
                    Name          = $Field.name
                    ReferenceName = $Field.referenceName
                    Type          = $Field.type
                    Error         = $_.Exception.Message
                    Action        = 'Auto-resolution Failed'
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
