#https://learn.microsoft.com/en-us/rest/api/azure/devops/dashboard/dashboards/list

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
        # GET https://dev.azure.com/{organization}/{project}/{team}/_apis/dashboard/dashboards?api-version=7.1-preview.3
        $ids = @()
        $ids += if (-not $Id) {
            $allDashboards = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Project $Project `
                -Endpoint "dashboard/dashboards" `
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
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Project $Project `
                -Endpoint "dashboard/dashboards/$dashboardId" `
                -NoRetry:$NoRetry
        }
    }
}