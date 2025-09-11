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
        [Switch]$NoRetry
    )

    try {
        $fieldToImport = $Field.PSObject.Copy()
        # Ensure field reference name includes process namespace for portability
        if ($fieldToImport.referenceName -notlike "*$ProcessName.*") {
            $fieldToImport.referenceName = "$ProcessName.$($fieldToImport.referenceName)"
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
        if ($Force) {
            Write-Warning "Could not create/update field '$($fieldToImport.referenceName)': $_"
        }
        else {
            Write-Verbose "Field $($fieldToImport.referenceName) may already exist: $_"
        }
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.Exception.Message
        }
    }
}
