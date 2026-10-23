<#
.SYNOPSIS
Creates work items with fields and optional parent or child links.

.DESCRIPTION
Creates work items with fields and optional parent or child links.

.PARAMETER Title
Titles of the work items to create.

.PARAMETER Project
Project that the work item is in.

.PARAMETER CollectionUri
The full Azure DevOps URL of an organization. Can be automatically populated in a pipeline.

.PARAMETER Pat
An Azure DevOps personal access token authorized to create work items.

.EXAMPLE
New-AzDOWorkItem -Title 'Example work item' -Project MyProject

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/create

.NOTES
N/A
#>
function New-AzDOWorkItem {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String[]]$Title,
        [String]$Type = 'User Story',
        [String]$AreaPath,
        [String]$IterationPath,
        [String]$Description = 'Created via AzDOCmd\New-AzDOWorkItem',
        [Int]$ParentId,
        [Int]$ChildId,
        [Switch]$SuppressNotifications,
        [Switch]$NoRetry,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
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
        $validType = Get-AzDOWorkItemType `
            -Type $Type `
            -NoRetry:$NoRetry `
            -Project $Project `
            -CollectionUri $CollectionUri `
            -Pat $Pat
        if (!$validType) {
            throw "Invalid work item type: $Type"
        }

        foreach ($item in $Title) {
            if (
                $PSCmdlet.ShouldProcess(
                    $CollectionUri, "Create work item $item of type $Type in project $Project"
                )
            ) {
                $descriptionFieldName = if ($Type -eq 'Bug') {
                    'Microsoft.VSTS.TCM.ReproSteps'
                }
                else {
                    'System.Description'
                }
                $body = @(
                    [PSCustomObject]@{
                        op    = 'add'
                        path  = '/fields/System.Title'
                        from  = $null
                        value = $item
                    },
                    [PSCustomObject]@{
                        op    = 'add'
                        path  = "/fields/$descriptionFieldName"
                        value = $Description
                    }
                )
                if ($AreaPath) {
                    if ($AreaPath -notlike "$Project*") {
                        $AreaPath = $Project + '\' + $AreaPath
                    }
                    $body += [PSCustomObject]@{
                        op    = 'add'
                        path  = '/fields/System.AreaPath'
                        value = $AreaPath
                    }
                }
                if ($IterationPath) {
                    if ($IterationPath -notlike "$Project*") {
                        $IterationPath = $Project + '\' + $IterationPath
                    }
                    $body += [PSCustomObject]@{
                        op    = 'add'
                        path  = '/fields/System.IterationPath'
                        value = $IterationPath
                    }
                }
                if ($ParentId) {
                    $body += [PSCustomObject]@{
                        op    = 'add'
                        path  = '/relations/-'
                        value = @{
                            rel = 'System.LinkTypes.Hierarchy-Reverse'
                            url = "$CollectionUri/$Project/_apis/wit/workItems/$ParentId"
                        }
                    }
                }
                if ($ChildId) {
                    $body += [PSCustomObject]@{
                        op    = 'add'
                        path  = '/relations/-'
                        value = @{
                            rel = 'System.LinkTypes.Hierarchy-Forward'
                            url = "$CollectionUri/$Project/_apis/wit/workItems/$ChildId"
                        }
                    }
                }

                $workItem = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Post `
                    -Project $Project `
                    -Endpoint "wit/workitems/`$$([Uri]::EscapeDataString($Type))" `
                    -Body (ConvertTo-Json -InputObject $body -Depth 10 -Compress) `
                    -Params @(
                        "suppressNotifications=$SuppressNotifications"
                        '$expand=All'
                    ) `
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
