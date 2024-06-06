<#
.SYNOPSIS
Gets file contents from a single file in a git repo.

.DESCRIPTION
Gets file contents from a single file in a git repo.

.PARAMETER Repository
Repo that the file is in.

.PARAMETER Branch
The branch to pull the file from.

.PARAMETER Path
Path from the source of the repository. Use `/` to divide folders, and no leading slash.

.PARAMETER OutFile
Saves the file contents to a file if specified.

.PARAMETER Project
Project that the file's repo resides in.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[organization]).

.PARAMETER Pat
Personal access token authorized to read code. Defaults to $env:SYSTEM_ACCESSTOKEN for use in
AzurePipelines.

.EXAMPLE
Get-AzDOGitItem -OutFile 'README.md'

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/git/items/get

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Get-AzDOGitItem {
    [CmdletBinding()]
    param (
        [Alias('Repo')]
        [String]$Repository = $env:BUILD_REPOSITORY_NAME,
        [string]$Branch = 'main',
        [string]$Path = 'README.md',
        [string]$OutFile,
        [Switch]$NoRetry,
        [String]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    Invoke-AzDORestApiMethod `
        -Method Get `
        -CollectionUri $CollectionUri `
        -Project $Project `
        -Endpoint "git/repositories/$Repository/items" `
        -Params (
            "scopePath=/$Path",
            'download=true',
            "version=$Branch",
            'versionOptions=None',
            'versionType=branch'
        ) `
        -OutFile:$OutFile `
        -Headers ( Initialize-AzDORestApi -Pat $Pat ) `
        -ApiVersion '7.1-preview.1' `
        -NoRetry:$NoRetry `
        -WhatIf:$WhatIfPreference
}
