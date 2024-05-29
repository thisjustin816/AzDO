<#
.SYNOPSIS
Updates a field in a work item.

.DESCRIPTION
Updates a field in a work item.

.PARAMETER Id
ID of the work item.

.PARAMETER Field
The work item field to update.

.PARAMETER Value
The value to populate the field with.

.PARAMETER Project
Project that the work item is in.

.PARAMETER CollectionUri
The full Azure DevOps URL of an organization. Can be automatically populated in a pipeline.

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to edit work items.

.EXAMPLE
Get-AzDOWorkItem -Id 12345 -Project MyProject | Set-AzDOWorkItemField -Name Title -Value 'A better title'

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/update

.NOTES
General notes
#>
function Set-AzDOWorkItemField {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Int[]]$Id,
        [Alias('Field')]
        [String]$Name,
        [String]$Value,
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

        foreach ($number in $id) {
            if ($PSCmdlet.ShouldProcess($CollectionUri, "Update work item $number with field $Name to value $Value in project $Project")) {
                $body = @(
                    @{
                        op    = 'add'
                        path  = "/fields/System.$Name"
                        value = $Value
                    }
                ) | ConvertTo-Json
                $body = "[`n$body`n]"

                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Patch `
                    -Project $Project `
                    -Endpoint "wit/workitems/$number" `
                    -Body $body `
                    -NoRetry:$NoRetry
            }
        }
    }
}
