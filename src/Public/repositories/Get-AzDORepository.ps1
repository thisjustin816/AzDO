<#
.SYNOPSIS
Gets info for an Azure Repos repository.

.DESCRIPTION
Gets info for an Azure Repos repository.

.PARAMETER Name
Name of the repo.

.PARAMETER Project
Project that the repo resides in.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[orgranization]).

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to read code.

.EXAMPLE
Get-AzDORepository -Name AzDO -Project MyProject

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/get%20repository

.NOTES
N/A
#>
function Get-AzDORepository {
    [CmdletBinding()]
    param (
        [String]$Name,
        [Switch]$NoRetry,
        [String]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1-preview.1'
        }
    }

    process {
        Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Project $Project `
            -Endpoint "git/repositories/$Name" `
            -NoRetry:$NoRetry
    }
}
