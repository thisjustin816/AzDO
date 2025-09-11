<#
.SYNOPSIS
Imports a single custom behavior into an Azure DevOps process.

.DESCRIPTION
This private helper function manages the creation or update of a single custom behavior within a
work item process. It handles the logic for sanitizing the behavior object by removing
organization-specific properties and filters out known org-specific behaviors (identified by a
GUID pattern in their reference name).

The function first attempts to create the behavior via a POST request. If that fails and the
-Force switch is specified, it will attempt to update the existing behavior via a PUT request.
This allows for idempotent imports.

.PARAMETER Behavior
The PSObject representing the behavior to be imported.

.PARAMETER ProcessId
The GUID of the process to which the behavior will be added.

.PARAMETER ApiHeaders
The pre-initialized hashtable of API headers required for making REST calls.

.PARAMETER PropertiesToRemove
An array of property names to be removed from the behavior object before import.

.PARAMETER Force
If specified, the function will attempt to update an existing behavior if creation fails.

.PARAMETER NoRetry
A switch to disable the default retry mechanism for REST API calls.

.EXAMPLE
Import-AzDOBehavior -Behavior $behavior -ProcessId $pid -ApiHeaders $headers -Force
This example imports the specified $behavior into the process identified by $pid.

.NOTES
This is a private helper function and is not intended for direct use. It is dot-sourced by
the Import-AzDOWorkItemProcess function.
#>
function Import-AzDOBehavior {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Behavior,
        [Parameter(Mandatory = $true)]
        [String]$ProcessId,
        [Parameter(Mandatory = $true)]
        [Hashtable]$ApiHeaders,
        [Parameter(Mandatory = $true)]
        [String[]]$PropertiesToRemove,
        [Switch]$Force,
        [Switch]$NoRetry
    )

    # Skip organization-specific GUID behaviors
    $guidPattern = '^Custom\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if ($Behavior.referenceName -match $guidPattern) {
        Write-Warning "Skipping org-specific behavior: $($Behavior.name) ($($Behavior.referenceName))"
        return [PSCustomObject]@{
            Success       = $true
            Skipped       = $true
            Name          = $Behavior.name
            ReferenceName = $Behavior.referenceName
            Reason        = 'Organization-specific GUID'
        }
    }

    try {
        $cleanBehavior = Clear-AzDOObjectOrgData -InputObject $Behavior -PropertiesToRemove $PropertiesToRemove

        $behaviorErrorAction = if ($Force) { 'Stop' } else { 'SilentlyContinue' }
        Invoke-AzDORestApiMethod @ApiHeaders `
            -Method Post `
            -Endpoint "work/processes/$ProcessId/behaviors" `
            -Body ($cleanBehavior | ConvertTo-Json -Compress) `
            -NoRetry:$NoRetry -ErrorAction $behaviorErrorAction

        return [PSCustomObject]@{
            Success = $true
            Skipped = $false
        }
    }
    catch {
        if ($Force) {
            try {
                $cleanBehavior = Clear-AzDOObjectOrgData -InputObject $Behavior -PropertiesToRemove $PropertiesToRemove
                Invoke-AzDORestApiMethod @ApiHeaders `
                    -Method Put `
                    -Endpoint "work/processes/$ProcessId/behaviors/$($Behavior.referenceName)" `
                    -Body ($cleanBehavior | ConvertTo-Json -Compress) `
                    -NoRetry:$NoRetry -ErrorAction Stop
                return [PSCustomObject]@{
                    Success = $true
                    Skipped = $false
                }
            }
            catch {
                $errorMessage = "Could not import custom behavior '$($Behavior.name)': $_"
                Write-Warning $errorMessage
                return [PSCustomObject]@{
                    Success       = $false
                    Skipped       = $false
                    Name          = $Behavior.name
                    ReferenceName = $Behavior.referenceName
                    Error         = $_.Exception.Message
                }
            }
        }
        else {
            $errorMessage = "Custom behavior '$($Behavior.name)' could not be imported: $_"
            Write-Verbose $errorMessage
            return [PSCustomObject]@{
                Success       = $false
                Skipped       = $false
                Name          = $Behavior.name
                ReferenceName = $Behavior.referenceName
                Error         = $_.Exception.Message
            }
        }
    }
}
