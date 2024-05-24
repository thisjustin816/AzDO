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
function Get-AzDOWorkItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
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
