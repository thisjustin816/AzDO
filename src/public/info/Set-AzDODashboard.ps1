<#
.SYNOPSIS
Creates or updates a dashboard in Azure DevOps.

.DESCRIPTION
Creates or updates a dashboard in Azure DevOps using the dashboard object from Get-AzDODashboard.

.PARAMETER Dashboard
The dashboard object to create or update.

.PARAMETER Team
The team project to create or update the dashboard in.

.PARAMETER NoRetry
If specified, the command will not retry on failure.

.PARAMETER Project
Project that the dashboard resides in.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[organization]).

.PARAMETER Pat
Personal access token authorized to administer dashboards. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
$dashboard = Get-AzDODashboard -Project MyProject -Name MyDashboard
Set-AzDODashboard -Dashboard $dashboard -Project MyProject

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/dashboard/dashboards/create
https://learn.microsoft.com/en-us/rest/api/azure/devops/dashboard/dashboards/update

.NOTES
M/A
#>

function Set-AzDODashboard {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]$Dashboard,
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
            ApiVersion    = '7.1-preview.2'
        }
    }

    process {
        $dashboardDisplayName = if ($Team) { "$Team/$($Dashboard.name)" } else { $Dashboard.name }
        if ($PSCmdlet.ShouldProcess("`"$dashboardDisplayName`" dashboard ($($Dashboard.id))", 'Set')) {
            Write-Host "Updating the `"$dashboardDisplayName`" dashboard ($($Dashboard.id)) in project: $Project"
            $method = 'Post'
            $endpoint = 'dashboard/dashboards'
            if ($Dashboard.id) {
                $method = 'Put'
                $endpoint += ('/' + $Dashboard.id)
            }
            $params = @{
                Method   = $method
                Project  = $Project
                Endpoint = $endpoint
                Body     = ( $Dashboard | ConvertTo-Json -Depth 10 )
                NoRetry  = $NoRetry
                Verbose  = $VerbosePreference
            }
            if ($Team) {
                $params['Team'] = $Team
            }
            $updatedDashboard = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                @params
            if ($updatedDashboard) {
                $updatedDashboard
            }
            else {
                Get-AzDODashboard `
                    -Id $Dashboard.id `
                    -Project $Project `
                    -Team $Team `
                    -CollectionUri $CollectionUri `
                    -Pat $Pat
            }
        }
    }
}
