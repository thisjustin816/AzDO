<#
.SYNOPSIS
Creates or updates widgets in a dashboard in Azure DevOps.

.DESCRIPTION
Creates or updates widgets in a dashboard in Azure DevOps using the dashboard object from Get-AzDODashboard.

.PARAMETER Dashboard
The dashboard object to create or update widgets in.

.PARAMETER Widgets
The array of widget objects to create or update.

.PARAMETER Team
The team project to create or update the widgets in.

.PARAMETER NoRetry
If specified, the command will not retry on failure.

.PARAMETER Project
Project that the dashboard resides in.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[organization]).

.PARAMETER Pat
Personal access token authorized to administer dashboards. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure Pipelines.

.EXAMPLE
$dashboard = Get-AzDODashboard -Project MyProject -Name MyDashboard
$widgets = Get-AzDODashboardWidget -Dashboard $dashboard -Project MyProject
Set-AzDODashboardWidget -Dashboard $dashboard -Widgets $widgets -Project MyProject

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/dashboard/widgets/replace

.NOTES
M/A
#>

function Set-AzDODashboardWidget {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]$Dashboard,
        [Parameter(Mandatory = $true)]
        [Object[]]$Widgets,
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
            Write-Host "Replacing widgets in the `"$dashboardDisplayName`" dashboard ($($Dashboard.id)) in project: $Project"
            $endpoint = "dashboard/dashboards/$($Dashboard.id)/widgets"
            $params = @{
                Method   = 'Put'
                Project  = $Project
                Endpoint = $endpoint
                Body     = ( @{ widgets = $Widgets } | ConvertTo-Json -Depth 10 )
                NoRetry  = $NoRetry
                Verbose  = $VerbosePreference
            }
            if ($Team) {
                $params['Team'] = $Team
            }
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                @params
        }
    }
}
