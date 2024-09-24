<#
.SYNOPSIS
Removes a tag from a build.

.DESCRIPTION
Removes a tag from a build, multiple tags, or all tags if none are specified.

.PARAMETER Tag
Tag(s) to remove from the build.

.PARAMETER BuildId
ID of the build to remove tags from.

.PARAMETER Project
Project that the build's pipeline resides in.

.PARAMETER CollectionUri
The Project Collection URI (https://dev.azure.com/[organization])

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to manage pipelines.

.PARAMETER Force
Don't ask for confirmation before removing the tags.

.EXAMPLE
Get-AzDOPipelineRun -Id 11111 -Project Tools | Remove-AzDOPipelineRunTag -Tag tag1, tag2
Removes tags tag1 and tag2 from build 11111.

.EXAMPLE
Get-AzDOPipelineRun -Id 11111 -Project Tools | Remove-AzDOPipelineRunTag
Removes all tags from build 11111.

.NOTES
N/A

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/tags/delete%20build%20tag
#>
function Remove-AzDOPipelineRunTag {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0)]
        [Alias('Tags')]
        [String[]]$Tag,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [String[]]
        $BuildId = $env:BUILD_BUILDID,
        [Switch]
        $NoRetry,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]
        $Project = $env:SYSTEM_TEAMPROJECT,
        [String]
        $CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]
        $Pat = $env:SYSTEM_ACCESSTOKEN,
        [Switch]
        $Force
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '5.1'
        }
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        foreach ($id in $buildId) {
            if (!$Tag) {
                $Tag = Get-AzDOPipelineRunTag `
                    -BuildId $id `
                    -Project $Project `
                    -CollectionUri $CollectionUri `
                    -Pat $Pat `
                    -NoRetry:$NoRetry
            }
            foreach ($buildTag in $Tag) {
                if (!$Force) {
                    $ConfirmPreference = 'Low'
                }
                if ($PSCmdlet.ShouldProcess("Build $id", "Remove tag $buildTag")) {
                    Invoke-AzDORestApiMethod `
                        @script:AzApiHeaders `
                        -Method Delete `
                        -Project $Project `
                        -Endpoint "build/builds/$id/tags/$buildTag" `
                        -Body $body `
                        -NoRetry:$NoRetry `
                        -WhatIf:$false `
                        -Confirm:$false
                }
            }
        }
    }
}
