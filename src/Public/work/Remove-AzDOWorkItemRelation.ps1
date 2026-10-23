<#
.SYNOPSIS
Removes a specific relationship from a work item.

.DESCRIPTION
The Remove-AzDOWorkItemRelation function removes a specific relationship from a work item in Azure DevOps.

.PARAMETER Id
The ID of the work item.

.PARAMETER RelationType
Required. The type of relationship to remove: Parent, Child, Successor, Predecessor, or Related.

.PARAMETER NoRetry
Switch to disable retry attempts on API calls.

.PARAMETER Project
The name or ID of the project.

.PARAMETER CollectionUri
The URI of the Azure DevOps collection.

.PARAMETER PAT
The Personal Access Token to authenticate with Azure DevOps.

.EXAMPLE
Remove-AzDOWorkItemRelation -Id 12345 -RelationType Parent -Project MyProject

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/update

.NOTES
N/A
#>
function Remove-AzDOWorkItemRelation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Int[]]$Id,

        [Parameter(Mandatory)]
        [ValidateSet('Parent', 'Child', 'Successor', 'Predecessor', 'Related')]
        [String]$RelationType,

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
        $Project = $Project | Get-AzDOApiProjectName

        $relationTypeMap = Get-AzDOWorkItemRelationTypeMap

        $apiRelationType = $relationTypeMap[$RelationType]

        foreach ($workItemId in $Id) {
            $workItem = Get-AzDOWorkItem `
                -Id $workItemId `
                -Project $Project `
                -NoRetry:$NoRetry `
                -CollectionUri $CollectionUri `
                -Pat $Pat

            $linkIndex = @(
                $workItem.relations |
                    Where-Object { $_.rel -eq $apiRelationType } |
                    ForEach-Object { $workItem.relations.IndexOf($_) } |
                    Sort-Object -Descending
            )

            if ($linkIndex.Count -gt 0) {
                $body = @()
                $body += foreach ($index in $linkIndex) {
                    @{
                        op   = 'remove'
                        path = "/relations/$index"
                    }
                }

                if ($PSCmdlet.ShouldProcess($CollectionUri, "Remove $RelationType link(s) from work item $workItemId in project $Project")) {
                    Invoke-AzDORestApiMethod `
                        @script:AzApiHeaders `
                        -Method Patch `
                        -Project $Project `
                        -Endpoint "wit/workitems/$WorkItemId" `
                        -Body (ConvertTo-Json -InputObject $body -Compress) `
                        -NoRetry:$NoRetry
                }
            }
            else {
                Write-Warning -Message "No $RelationType link found on work item $workItemId in project $Project."
            }
        }
    }
}
