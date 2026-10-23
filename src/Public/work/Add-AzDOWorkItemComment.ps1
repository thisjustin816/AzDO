<#
.SYNOPSIS
Adds a comment to a work item.

.DESCRIPTION
Adds a comment to a work item.

.PARAMETER Id
ID of the work item.

.PARAMETER Comment
The comment to add.

.PARAMETER Project
Project that the work item is in.

.PARAMETER CollectionUri
The full Azure DevOps URL of an organization. Can be automatically populated in a pipeline.

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to edit work items.

.EXAMPLE
Get-AzDOWorkItem -Id 12345 -Project MyProject | Add-AzDOWorkItemComment -Comment 'Insert comment here'

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/update

.NOTES
N/A
#>
function Add-AzDOWorkItemComment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [String[]]$Id,
        [String]$Comment,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    process {
        Set-AzDOWorkItemField `
            -Id $Id `
            -Name History `
            -Value $Comment `
            -Project $Project `
            -CollectionUri $CollectionUri `
            -Pat $Pat |
            ForEach-Object -Process {
                [PSCustomObject]@{
                    Id      = $_.id
                    Type    = $_.fields | Select-Object -ExpandProperty System.WorkItemType
                    Title   = $_.fields | Select-Object -ExpandProperty System.Title
                    Comment = $_.fields | Select-Object -ExpandProperty System.History
                    Url     = $_.url.Replace(
                        "_apis/wit/workItems/$($_.id)",
                        "_workitems/edit/$($_.id)"
                    )
                }
            }
    }
}
