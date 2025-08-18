<#
.SYNOPSIS
Downloads an artifact from a given build.

.DESCRIPTION
Downloads an artifact from a given build.

.PARAMETER BuildId
ID of the build to download from.

.PARAMETER ArtifactName
Name of the artifact to download. If nothing is specified, all artifacts will be downloaded.

.PARAMETER SubPath
Download just the subpath of an artifact.

.PARAMETER Destination
Destination directory path for the downloaded files.

.PARAMETER List
If specified, will list the names and download URLs of the artifacts instead of downloading.

.PARAMETER Project
Project that the build's pipeline resides in.

.PARAMETER Pat
Personal access token authorized to administer builds. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
Get-AzDOArtifact -BuildId 12345

.EXAMPLE
Get-AzDOPipeline -Name 'MyPipeline' -Project 'MyProject' |
    Get-AzDOPipelineRunList -MaxRuns 1 |
    Get-AzDOArtifact -Destination $env:USERPROFILE/Downloads -ArtifactName 'MyArtifact*'

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/Artifacts/Get

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Get-AzDOArtifact {
    [CmdletBinding(DefaultParameterSetName = 'Get')]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Alias('id')]
        [Int]
        $BuildId,

        [Parameter(ParameterSetName = 'Get')]
        [Parameter(ParameterSetName = 'List')]
        [Parameter(ParameterSetName = 'SubPath', Mandatory = $true)]
        [Alias('name')]
        [String]
        $ArtifactName,

        [Parameter(ParameterSetName = 'Get')]
        [Parameter(ParameterSetName = 'SubPath')]
        [String]
        $SubPath,

        [Parameter(ParameterSetName = 'Get')]
        [String]
        $Destination = $PWD,

        [Parameter(ParameterSetName = 'List')]
        [Switch]
        $List,

        [Switch]
        $NoRetry,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]
        $Project = $env:SYSTEM_TEAMPROJECT,

        [String]
        $CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [String]
        $Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzDOApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '6.1'
        }
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        try {
            $artifacts = Invoke-AzDORestApiMethod `
                @script:AzDOApiHeaders `
                -Method Get `
                -Endpoint "build/builds/$BuildId/artifacts" `
                -Project $Project `
                -NoRetry:$NoRetry `
                -WhatIf:$false |
                ForEach-Object -Process {
                    [PSCustomObject]@{
                        Name = $_ | Select-Object -ExpandProperty name
                        Url  = $_.resource | Select-Object -ExpandProperty downloadUrl
                    }
                }
        }
        catch {
            Write-Verbose -Message (
                'No response from Azure DevOps. Check the PAT stored in $env:SYSTEM_ACCESSTOKEN.'
            )
        }
        if ($ArtifactName) {
            $artifacts = $artifacts | Where-Object -Property name -Match $ArtifactName
        }
        if ($List) {
            $artifacts
        }
        else {
            if ($artifacts.Name) {
                $activity = "Download Artifacts: $($artifacts.Name -join ', ')"
                Write-Verbose -Message $activity
                foreach ($artifact in $artifacts) {
                    $newName = if ($SubPath) {
                        ( Split-Path -Path $SubPath -Leaf ) -replace '[\s]', '_'
                    }
                    else {
                        $artifact.Name -replace '[\s]', '_'
                    }
                    $displayName = if ($SubPath) {
                        $artifact.Name + '/' + $newName
                    }
                    else {
                        $newName
                    }
                    Write-Verbose -Message "Downloading $displayName..."
                    $progress = @{
                        Activity         = $activity
                        Status           = 'Downloading...'
                        CurrentOperation = $displayName
                    }
                    Write-Progress @progress
                    $cachedProgressPreference = $ProgressPreference
                    $ProgressPreference = 'SilentlyContinue'
                    <#
                    $guidFilter = (
                        '(\{){0,1}' +
                        '[0-9a-fA-F]{8}' +
                        '\-[0-9a-fA-F]{4}' +
                        '\-[0-9a-fA-F]{4}' +
                        '\-[0-9a-fA-F]{4}' +
                        '\-[0-9a-fA-F]{12}' +
                        '(\}){0,1}'
                    )
                    $uri = $artifact.Url -replace $guidFilter, $Project
                    #>
                    $uri = $artifact.Url
                    if ($SubPath) {
                        $uri += '&subPath=/' + $SubPath
                    }
                    New-Item -Path $Destination -ItemType Directory -Force -ErrorAction SilentlyContinue |
                        ForEach-Object -Process {
                            Write-Verbose -Message $_
                        }
                    Invoke-WebRequest `
                        -Uri $uri `
                        -Headers $script:AzDOApiHeaders['Headers'] `
                        -UseBasicParsing `
                        -OutFile "$Destination/$newName.zip"
                    $ProgressPreference = $cachedProgressPreference
                    Get-Item -Path "$Destination/$newName.zip"
                    Write-Progress -Activity $activity -Completed
                }
            }
        }
        if (!$artifacts) {
            $warningMessage = 'No artifacts found '
            if ($ArtifactName) {
                $warningMessage += "matching '$ArtifactName' "
            }
            $warningMessage += "for build $BuildId."
            Write-Warning -Message $warningMessage
        }
    }
}
