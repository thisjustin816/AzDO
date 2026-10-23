<#
.SYNOPSIS
Gets work item types for a project.

.DESCRIPTION
Gets work item types for a project.

.PARAMETER Type
Filter by work item type.

.PARAMETER NoRetry
Don't retry failed calls.

.PARAMETER Project
Project to list work item types for.

.PARAMETER CollectionUri
The full Azure DevOps URL of an organization. Can be automatically populated in a pipeline.

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to read work items.

.EXAMPLE
Get-AzDOWorkItemType -Project 'MyProject'

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-item-types/list

.NOTES
N/A
#>
function Get-AzDOWorkItemType {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param (
        [String[]]$Type,
        [Switch]$NoRetry,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
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
        $processId = Get-AzDOProject -Name $Project -NoRetry:$NoRetry -CollectionUri $CollectionUri -Pat $Pat |
            Select-Object -ExpandProperty capabilities |
            Select-Object -ExpandProperty processTemplate |
            Select-Object -ExpandProperty templateTypeId

        $types = @(
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$processId/workitemtypes" `
                -NoRetry:$NoRetry
        )
        if ($Type) {
            $types | Where-Object -FilterScript { $Type -contains $_.name }
        }
        else {
            $types
        }
    }
}
