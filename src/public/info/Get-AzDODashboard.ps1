<#
.SYNOPSIS
Gets dashboard objects from Azure DevOps.

.DESCRIPTION
Gets dashboard objects from Azure DevOps using a project and optional name or ID filter.

.PARAMETER Name
A filter to search for dashboard names.

.PARAMETER Id
The dashboard ID to get.

.PARAMETER Project
Project that the dashboards reside in.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[organization]).

.PARAMETER Pat
Personal access token authorized to administer dashboards. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
Get-AzDODashboard -Project MyProject -Name MyDashboard*

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/dashboard/dashboards/list

.NOTES
M/A
#>

function Get-AzDODashboard {
    [CmdletBinding()]
    param (
        [String[]]$Name,
        [String[]]$Id,
        [Switch]$NoRetry,
        [String]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1-preview.3'
        }
    }

    process {
        $ids = @()
        $ids += if (-not $Id) {
            $allDashboards = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Project $Project `
                -Endpoint 'dashboard/dashboards' `
                -NoRetry:$NoRetry
            if ($Name) {
                $allDashboards | Where-Object -Property name -In $Name | Select-Object -ExpandProperty id
            }
            else {
                $allDashboards.id
            }
        }
        else {
            $Id
        }

        foreach ($dashboardId in $ids) {
            try {
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -Project $Project `
                    -Endpoint "dashboard/dashboards/$dashboardId" `
                    -NoRetry:$NoRetry `
                    -ErrorAction Stop
            }
            catch {
                Write-Warning $_.Exception.Message
                continue
            }
        }
    }
}
