<#
.SYNOPSIS
Retrieves Azure DevOps queries.

.DESCRIPTION
This function retrieves queries from Azure DevOps using the REST API.

.PARAMETER Id
Specifies the ID of the query to retrieve. If not provided, all queries will be retrieved.

.PARAMETER Expand
Specifies the expand parameter for the query. Default is 'All'.

.PARAMETER Depth
Specifies the depth parameter for the query. Default is 1.

.PARAMETER NoRetry
Switch to disable retry logic.

.PARAMETER Project
The name of the Azure DevOps project. Defaults to the environment variable SYSTEM_TEAMPROJECT.

.PARAMETER CollectionUri
The URI of the Azure DevOps collection. Defaults to the environment variable SYSTEM_COLLECTIONURI.

.PARAMETER Pat
The personal access token for Azure DevOps. Defaults to the environment variable SYSTEM_ACCESSTOKEN.

.EXAMPLE
Get-AzDOQuery -Project 'MyProject' -Pat 'myPatToken'

.EXAMPLE
Get-AzDOQuery -Project 'MyProject' -Pat 'myPatToken' -QueryId '12345'

.NOTES
N/A

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/queries/list
#>
function Get-AzDOQuery {
    [CmdletBinding()]
    param (
        [String]$Id,
        [String]$Expand = 'All',
        [Int]$Depth = 1,
        [Switch]$NoRetry,
        [String]$Project = $env:SYSTEM_TEAMPROJECT,
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
        $endpoint = 'wit/queries'
        if ($QueryId) {
            $endpoint += "/$Id"
        }
        Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method 'Get' `
            -Project $Project `
            -Endpoint $endpoint `
            -Params @(
                "`$expand=$Expand",
                "`$depth=$Depth"
            ) `
            -NoRetry:$NoRetry
    }
}
