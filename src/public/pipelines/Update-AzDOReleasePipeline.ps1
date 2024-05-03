<#
.SYNOPSIS
Updates a release pipeline definition.

.DESCRIPTION
Updates a release pipeline definition using a provided json file.

.PARAMETER PipelineId
ID of the pipeline to update. Accepts values from the pipeline.

.PARAMETER Project
Project that the pipelines reside in.

.PARAMETER JsonFilePath
FilePath of the release definition json with updated values.

.PARAMETER Pat
Personal access token authorized to administer releases. Defaults to $env:SYSTEM_ACCESSTOKEN for use in
AzurePipelines.

.EXAMPLE
Update-AzDOReleasePipeline -PipelineId 5992 -Project Packages -JsonFilePath ./azure-pipelines/AzurePipelines-CI.json

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/release/definitions/update

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Update-AzDOReleasePipeline {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('id')]
        [String]$PipelineId,
        [String]$JsonFilePath,
        [Switch]$NoRetry,
        [String[]]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [string]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.2-preview.4'
        }
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Put `
            -Project $Project `
            -Endpoint "release/definitions/$PipelineId" `
            -Body ( Get-Content -Path $JsonFilePath -Encoding UTF8 | Out-String ) `
            -NoRetry:$NoRetry
    }
}