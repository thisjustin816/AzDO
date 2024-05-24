<#
.SYNOPSIS
Get a Work Item's info.

.DESCRIPTION
Get a Work Item's info.

.PARAMETER Id
ID of the work item.

.PARAMETER Project
Project that the work item is in.

.PARAMETER CollectionUri
The full Azure DevOps URL of an organization. Can be automatically populated in a pipeline.

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to read work items.

.EXAMPLE
Get-AzDOWorkItem -Id 12345 -Project MyProject

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/get-work-item

.NOTES
N/A
#>
function New-AzDOWorkItem {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [String[]]$Title,
        [String]$Type = 'User Story',
        [Switch]$SuppressNotifications,
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
        foreach ($item in $Title) {
            if ($PSCmdlet.ShouldProcess($CollectionUri, "Create work item $item of type $Type in project $Project")) {
                $body = @(
                    [PSCustomObject]@{
                        op    = 'add'
                        path = '/fields/System.Title'
                        value = $item
                    }
                ) | ConvertTo-Json -Compress

                $workItem = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Post `
                    -Project $Project `
                    -Endpoint "wit/workitems/$([Uri]::EscapeDataString($Type))" `
                    -Body $body `
                    -Params @(
                        "suppressNotifications=$SuppressNotifications"
                    )
                    -NoRetry:$NoRetry
                $workItem | Add-Member `
                    -MemberType NoteProperty `
                    -Name project `
                    -Value $workItem.fields.'System.TeamProject'
                $workItem
            }
        }
    }
}
