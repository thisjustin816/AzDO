<#
.SYNOPSIS
Adds specific relationships to a work item.

.DESCRIPTION
The Add-AzDOWorkItemRelation function adds specific relationships to a work item in Azure DevOps.

.PARAMETER Id
The ID of the work item.

.PARAMETER RelationType
The types of the relationships to add.

.PARAMETER RelatedWorkItemId
The ID of the work item to link to.

.PARAMETER NoRetry
Switch to disable retry attempts on API calls.

.PARAMETER Project
The name or ID of the project.

.PARAMETER CollectionUri
The URI of the Azure DevOps collection.

.PARAMETER PAT
The Personal Access Token to authenticate with Azure DevOps.

.EXAMPLE
Add-AzDOWorkItemRelation -Id 123 -RelationType 'Parent','Child' -RelatedWorkItemId 456 -CollectionUri 'https://dev.azure.com/mycollection' -Project 'myproject' -PAT 'mypat'

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/update

.NOTES
N/A
#>
function Add-AzDOWorkItemRelation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Int[]]$Id,

        [ValidateSet('Parent', 'Child', 'Successor', 'Predecessor', 'Related')]
        [String[]]$RelationType,

        [Parameter(Mandatory = $true)]
        [Int]$RelatedWorkItemId,

        [Switch]$NoRetry,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,

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
        . $PSScriptRoot/../../private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        $relationTypeMap = & $PSScriptRoot/../../private/AzDOWorkItemRelationTypeMap.ps1

        foreach ($workItemId in $Id) {
            foreach ($relation in $RelationType) {
                $apiRelationType = $relationTypeMap[$relation]

                if ($PSCmdlet.ShouldProcess($CollectionUri, "Add $relation link from work item $workItemId to work item $RelatedWorkItemId in project $Project")) {
                    $relatedWorkItem = Get-AzDOWorkItem -Id $RelatedWorkItemId -NoRetry:$NoRetry -CollectionUri $CollectionUri -Project $Project -Pat $Pat

                    $body = @(
                        @{
                            op    = 'add'
                            path  = "/relations/-"
                            value = @{
                                rel = $apiRelationType
                                url = $relatedWorkItem.url
                            }
                        }
                    ) | ConvertTo-Json -Compress

                    Invoke-AzDORestApiMethod `
                        @script:AzApiHeaders `
                        -Method Patch `
                        -Project $Project `
                        -Endpoint "wit/workitems/$workItemId" `
                        -Body $body `
                        -NoRetry:$NoRetry
                }
            }
        }
    }
}
