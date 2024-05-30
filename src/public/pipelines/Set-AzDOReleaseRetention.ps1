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
Get-AzDOReleasePipeline -Name 'MyRelease' -Project 'MyProject' |
    Set-AzDOReleaseRetention -DaysToKeep 30 -ReleasesToKeep 3

id name    retentionPolicy
-- ----    ---------------
 1 Stage 1 @{daysToKeep=30; releasesToKeep=3; retainBuild=True}

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

function Set-AzDOReleaseRetention {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('id')]
        [String]$PipelineId,
        [String[]]$Environment,
        [Int]$DaysToKeep = 30,
        [Int]$ReleasesToKeep = 3,
        [Switch]$NoRetry,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,
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
        . $PSScriptRoot/../../private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        $releaseDefinition = Get-AzDOReleasePipeline `
            -Id $PipelineId `
            -NoRetry:$NoRetry `
            -Project $Project `
            -CollectionUri $CollectionUri `
            -Pat $Pat

        $exportedDefinitionFile = $releaseDefinition |
            Export-AzDOPipeline `
                -Destination $env:TEMP `
                -NoRetry:$NoRetry `
                -Project $Project `
                -CollectionUri $CollectionUri `
                -Pat $Pat
        $exportedDefinition = $exportedDefinitionFile |
            Get-Content -Raw -Encoding utf8 |
            ConvertFrom-Json -Depth 10
        $exportedDefinitionFile | Remove-Item -Force

        $environmentsToSet = if ($Environment) {
            foreach ($env in $Environment) {
                $exportedDefinition.environments.name | Where-Object -FilterScript { $_ -eq $env }
            }
        }
        else {
            $exportedDefinition.environments.name
        }

        foreach ($env in $environmentsToSet) {
            $exportedDefinition.environments |
                Where-Object -Property name -EQ $env |
                ForEach-Object -Process {
                    $_.retentionPolicy.daysToKeep = $DaysToKeep
                    $_.retentionPolicy.releasesToKeep = $ReleasesToKeep
                    $_.retentionPolicy.retainBuild = $true
                }
        }

        if ($PSCmdlet.ShouldProcess(
            "Pipeline: $PipelineId",
            "Update retention policy to keep $ReleasesToKeep builds and $DaysToKeep days."
        )) {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Put `
                -SubDomain vsrm `
                -Project $Project `
                -Endpoint "release/definitions/$PipelineId" `
                -Body ( $exportedDefinition | ConvertTo-Json -Depth 10 -Compress ) `
                -NoRetry:$NoRetry |
                Select-Object -ExpandProperty environments |
                Where-Object -FilterScript { $environmentsToSet -contains $_.name } |
                Select-Object -Property id, name, retentionPolicy
        }
    }
}
