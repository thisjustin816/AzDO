<#
.SYNOPSIS
Creates or updates a dashboard in Azure DevOps.

.DESCRIPTION
Creates or updates a dashboard in Azure DevOps using the dashboard object from Get-AzDODashboard.

.PARAMETER Dashboard
The dashboard object to create or update.

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
        # if ($Dashboard.id) {
        #     Get-AzDODashboard
        # }
        $endpoint = if ($Dashboard.id) {
            Write-Host "Updating the `"$($Dashboard.name)`" dashboard ($($Dashboard.id)) in project: $Project"
            "dashboard/dashboards/$($Dashboard.id)"
        }
        else {
            Write-Host "Creating the `"$($Dashboard.name)`" dashboard in project: $Project"
            "dashboard/dashboards"
        }

        if ($PSCmdlet.ShouldProcess("`"$($Dashboard.name)`" dashboard ($($Dashboard.id))", "Set")) {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Post `
                -Project $Project `
                -Endpoint $endpoint `
                -Body ( $Dashboard | ConvertTo-Json -Depth 10 ) `
                -NoRetry:$NoRetry
        }
    }
}
