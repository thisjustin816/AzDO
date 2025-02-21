<#
.SYNOPSIS
Gets information for an Azure DevOps project.

.DESCRIPTION
Gets information for an Azure DevOps project.

.PARAMETER Name
Name of the project.

.PARAMETER CollectionUri
https://dev.azure.com/[organization]

.PARAMETER Pat
A personal access token authorized as a reader for the collection.

.EXAMPLE
Get-AzDOProject -Name MyProject

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/core/teams/get-teams

.NOTES
N/A
#>
function Get-AzDOTeam {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String[]]$Name,
        [Switch]$NoRetry,
        [String]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.2-preview.3'
        }
    }

    process {
        $allTeams = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method 'Get' `
            -Endpoint "projects/$Project/teams" `
            -NoRetry:$NoRetry

        if ($Name) {
            $allTeams | Where-Object { $Name -contains $_.name }
        }
    }
}
