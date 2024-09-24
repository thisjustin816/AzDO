<#
.SYNOPSIS
Gets tags from a build.

.DESCRIPTION
Gets tags from a build.

.PARAMETER BuildId
ID of the build to get tags from.

.PARAMETER NoRetry
Don't retry the API call if it fails.

.PARAMETER Project
Project that the build's pipeline resides in.

.PARAMETER CollectionUri
The Project Collection URI (https://dev.azure.com/[organization])

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to view pipelines.

.EXAMPLE
Get-AzDOPipelineRunTag -BuildId 11111 -Project Tools
Gets all tags from build 11111.

.NOTES
General notes

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/tags/get%20tags
#>
function Get-AzDOPipelineRunTag {
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
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

        foreach ($id in $BuildId) {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Project $Project `
                -Endpoint "build/builds/$id/tags" `
                -NoRetry:$NoRetry
        }
    }
}
