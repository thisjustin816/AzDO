<#
.SYNOPSIS
Gets user information based on the given PAT.

.DESCRIPTION
Gets user information based on the given PAT.

.PARAMETER CollectionUri
URI of the organization that the PAT belongs to.

.PARAMETER Pat
Azure DevOps personal access token.

.EXAMPLE
Get-AzDOPatIdentity

.NOTES
N/A
#>
function Get-AzDOPatIdentity {
    [CmdletBinding()]
    param (
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    $script:AzApiHeaders = @{
        Headers       = Initialize-AzDORestApi -Pat $Pat
        CollectionUri = $CollectionUri
        ApiVersion    = '7.1-preview.1'
    }

    try {
        Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method 'Get' `
            -Endpoint 'connectionData' `
            -NoRetry:$NoRetry `
            -ErrorAction Stop
    }
    catch {
        Write-Warning -Message "No valid identity found for the given Personal Access Token at $CollectionUri"
    }
}
