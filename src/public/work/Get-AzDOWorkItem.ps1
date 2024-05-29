<#
.SYNOPSIS
Get a Work Item's info.

.DESCRIPTION
Get a Work Item's info.

.PARAMETER Id
ID of the work item.

.PARAMETER Title
Title of the work item.

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

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/wiql/query-by-wiql

.NOTES
N/A
#>
function Get-AzDOWorkItem {
    [CmdletBinding(DefaultParameterSetName = 'ID')]
    param (
        [Parameter(ParameterSetName = 'ID', Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Int[]]$Id,
        [Parameter(ParameterSetName = 'Title', Mandatory = $true, Position = 0)]
        [String]$Title,
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
        if ($Title) {
            $body = @{
                query = "SELECT [System.Id] FROM workitems WHERE [System.Title] CONTAINS '$Title'"
            } | ConvertTo-Json -Compress

            $Id = @(
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Post `
                    -Project $Project `
                    -Endpoint "wit/wiql" `
                    -Body $body `
                    -NoRetry:$NoRetry |
                    Select-Object -ExpandProperty workItems |
                    Select-Object -ExpandProperty id
            )
            if (!$Id) {
                Write-Warning -Message "No work items found with title $Title in project $Project."
            }
        }

        foreach ($item in $Id) {
            $workItem = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Project $Project `
                -Endpoint "wit/workitems/$item" `
                -NoRetry:$NoRetry
            $workItem | Add-Member `
                -MemberType NoteProperty `
                -Name project `
                -Value $workItem.fields.'System.TeamProject'
            $workItem
        }
    }
}
