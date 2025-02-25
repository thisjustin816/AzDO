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

function New-AzDODashboard {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [String]$Name,
        [Object[]]$Widget,
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
        $body = @{
            name    = $Name
            widgets = $Widgets
        } | ConvertTo-Json -Depth 10
        Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method 'Put' `
            -Project $Project `
            -Team $Team `
            -Endpoint 'dashboard/dashboards' `
            -Body $body `
            -NoRetry:$NoRetry
    }
}
