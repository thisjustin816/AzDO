<#
.SYNOPSIS
Sets or updates an Azure DevOps query.

.DESCRIPTION
This function sets or updates an Azure DevOps query using the provided parameters.
It can either create a new query or update an existing one based on the provided Id or Path.

.PARAMETER Id
The ID of the query to update.

.PARAMETER Path
The path where the query should be created or updated.

.PARAMETER Name
The name of the query.

.PARAMETER Wiql
The WIQL (Work Item Query Language) query string.

.PARAMETER Columns
The columns to include in the query results.

.PARAMETER SortColumns
The columns to sort the query results by.

.PARAMETER NoRetry
A switch to disable retry logic.

.PARAMETER Project
The name of the Azure DevOps project. Defaults to the environment variable SYSTEM_TEAMPROJECT.

.PARAMETER CollectionUri
The URI of the Azure DevOps collection. Defaults to the environment variable SYSTEM_COLLECTIONURI.

.PARAMETER Pat
The Personal Access Token (PAT) for authentication. Defaults to the environment variable SYSTEM_ACCESSTOKEN.

.EXAMPLE
Set-AzDOQuery -Name "My Query" -Wiql "SELECT [System.Id] FROM WorkItems"

.NOTES
N/A
#>
function Set-AzDOQuery {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(ParameterSetName = 'Id', Position = 0, Mandatory = $true)]
        [String]$Id,
        [Parameter(ParameterSetName = 'Path', Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]$Name,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]$Wiql,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('queryType')]
        [ValidateSet('Flat', 'OneHop', 'Tree')]
        [String]$Type,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Object]$Columns,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Object]$SortColumns,
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
        $query = @{
            name        = $Name
            wiql        = $Wiql
            queryType   = $Type.ToLower()
            columns     = $Columns
            sortColumns = $SortColumns
        }
        if ($Id) {
            $query['id'] = $Id
        }
        if ($Path) {
            $query['path'] = $Path
        }
        $queryJson = ( $query | ConvertTo-Json -Depth 10 ) -replace
            ('(https:\/\/dev\.azure\.com\/[^\/]+\/[^\/]+)', $CollectionUri)

        $method = if ($Id) { 'Put' } else { 'Post' }
        $endpoint = if ($Id) { "wit/queries/$Project/$Id" } else { "wit/queries/$Project/$Path" }
        $params = @{
            Method   = $method
            Project  = $Project
            Endpoint = $endpoint
            Body     = ( $query | ConvertTo-Json -Depth 10 )
            NoRetry  = $NoRetry
            Verbose  = $VerbosePreference
        }
        if ($PSCmdlet.ShouldProcess($endpoint, 'Set')) {
            $updatedQuery = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                @params
            if ($updatedQuery) {
                $updatedQuery
            }
            else {
                Get-AzDOQuery `
                    -Name $Name `
                    -Project $Project `
                    -CollectionUri $CollectionUri `
                    -Pat $Pat
            }
        }
    }
}
