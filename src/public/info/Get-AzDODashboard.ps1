<#
.SYNOPSIS
Gets dashboard objects from Azure DevOps.

.DESCRIPTION
Gets dashboard objects from Azure DevOps using a project and optional name or ID filter.

.PARAMETER Name
A filter to search for dashboard names.

.PARAMETER Id
The dashboard ID to get.

.PARAMETER Team
The team project to get dashboards from.

.PARAMETER NoRetry
If specified, the command will not retry on failure.

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
        [String]$Team,
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
            $dashboardParams = @{
                Method   = 'Get'
                Project  = $Project
                Endpoint = 'dashboard/dashboards'
                NoRetry  = $NoRetry
            }
            if ($Team) {
                $dashboardParams['Team'] = $Team
            }
            $allDashboards = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                @dashboardParams
            if ($Name) {
                $allDashboards |
                    Where-Object -FilterScript { $Name -contains $_.name } |
                    Select-Object -ExpandProperty id
            }
            else {
                if (-not $Team) {
                    $allDashboards |
                        Where-Object -Property dashboardScope -EQ 'project' |
                        Select-Object -ExpandProperty id
                }
                else {
                    $allDashboards.id
                }
            }
        }
        else {
            $Id
        }

        foreach ($dashboardId in $ids) {
            try {
                $dashboard = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method 'Get' `
                    -Team $Team `
                    -Project $Project `
                    -Endpoint "dashboard/dashboards/$dashboardId" `
                    -NoRetry:$NoRetry `
                    -ErrorAction Stop
                if ($Team) {
                    $teamObj = Get-AzDOTeam `
                        -Name $Team `
                        -Project $Project `
                        -NoRetry:$NoRetry `
                        -CollectionUri $CollectionUri `
                        -Pat $Pat
                    $dashboard | Add-Member -MemberType NoteProperty -Name Team -Value $teamObj
                }
                $dashboard
            }
            catch {
                Write-Warning $_.Exception.Message
                continue
            }
        }
    }
}
