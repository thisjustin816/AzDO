<#
.SYNOPSIS
Adds a tag to a build.

.DESCRIPTION
Adds a tag to a build, or multiple tags.

.PARAMETER Tag
Tag(s) to add to a build.

.PARAMETER BuildId
ID of the build to add tags to.

.PARAMETER Project
Project that the build's pipeline resides in.

.PARAMETER CollectionUri
The Project Collection URI (https://dev.azure.com/[organization])

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to manage pipelines.

.EXAMPLE
Get-AzDOPipelineRun -Id 11111 -Project Tools | Add-AzDOPipelineRunTag tag1
Adds tag1 to build 11111

.NOTES
N/A

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/tags/add%20build%20tag
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/tags/add%20build%20tags
#>
function Add-AzDOPipelineRunTag {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('Tags')]
        [String[]]$Tag,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [String[]]
        $BuildId = $env:BUILD_BUILDID,
        [Switch]$NoRetry,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]
        $Project = $env:SYSTEM_TEAMPROJECT,
        [String]
        $CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]
        $Pat = $env:SYSTEM_ACCESSTOKEN
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
            if ($Tag.Count -eq 1) {
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Put `
                    -Project $Project `
                    -Endpoint "build/builds/$id/tags/$Tag" `
                    -NoRetry:$NoRetry `
                    -WhatIf:$WhatIfPreference
            }
            else {
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Post `
                    -Project $Project `
                    -Endpoint "build/builds/$id/tags" `
                    -Body ( $Tag | ConvertTo-Json ) `
                    -NoRetry:$NoRetry `
                    -WhatIf:$WhatIfPreference
            }
        }
    }
}
