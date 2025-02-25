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
            ApiVersion    = '7.1-preview.3'
        }
    }

    process {
        $dashboardDisplayName = if ($Team) { "$dashboardDisplayName" } else { $Dashboard.name }
        if ($Dashboard.id) {
            $destinationEndpoint = "dashboard/dashboards/$($Dashboard.id)"
            $destinationDashboard = Get-AzDODashboard `
                @script:AzApiHeaders `
                -Id $Dashboard.id `
                -Project $Project `
                -Team $Team `
                -Endpoint $destinationEndpoint `
                -NoRetry:$NoRetry `
                -ErrorAction SilentlyContinue
            if ($destinationDashboard) {
                Write-Host "Updating the `"$dashboardDisplayName`" dashboard ($($Dashboard.id)) in project: $Project"
                $endpoint = $destinationEndpoint
                $method = 'Put'
            }
            else {
                Write-Host "Creating the `"$dashboardDisplayName`" dashboard in project: $Project"
                $endpoint = "dashboard/dashboards"
                $method = 'Post'
            }
            
        }
        else {
            Write-Host "Creating the `"$dashboardDisplayName`" dashboard in project: $Project"
            $endpoint = "dashboard/dashboards"
            $method = 'Post'
        }

        if ($PSCmdlet.ShouldProcess("`"$dashboardDisplayName`" dashboard ($($Dashboard.id))", "Set")) {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method $method `
                -Project $Project `
                -Team $Team `
                -Endpoint $endpoint `
                -Body ( $Dashboard | ConvertTo-Json -Depth 10 ) `
                -NoRetry:$NoRetry
        }
    }
}
