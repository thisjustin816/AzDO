<#
.SYNOPSIS
Gets widgets from a dashboard in Azure DevOps.

.DESCRIPTION
Gets widgets from a dashboard in Azure DevOps using the dashboard object from Get-AzDODashboard.

.PARAMETER Dashboard
The dashboard object to get widgets from.

.PARAMETER Team
The team project to get widgets from.

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
Get-AzDODashboardWidget -Dashboard $dashboard -Project MyProject

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/dashboard/widgets/list

.NOTES
M/A
#>

function Get-AzDODashboardWidget {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
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
        Write-Host "Getting widgets for the `"$dashboardDisplayName`" dashboard ($($Dashboard.id)) in project: $Project"
        $endpoint = "dashboard/dashboards/$($Dashboard.id)/widgets"

        $params = @{
            Method   = 'Get'
            Project  = $Project
            Endpoint = $endpoint
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
