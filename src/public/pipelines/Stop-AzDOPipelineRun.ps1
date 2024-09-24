<#
.SYNOPSIS
Stops a build.

.DESCRIPTION
Stops a build by ID or object returned from another AzDOCmd build cmdlet.

.PARAMETER BuildId
The ID of the build to get.

.PARAMETER Project
Project that the build's pipeline resides in.

.PARAMETER Pat
Personal access token authorized to administer builds. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.PARAMETER PassThru
Outputs the cancelled build is passed.

.EXAMPLE
Get-AzDOPipeline -Name PipelineTest | Get-AzDOPipelineRunList -MaxBuilds 1 | Stop-AzDOPipelineRun
Stops the latest build in the PipelineTest build pipeline.

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/update%20build

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Stop-AzDOPipelineRun {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Alias('id')]
        [String[]]$BuildId,
        [Switch]$NoRetry,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN,
        [Switch]$PassThru
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '6.1'
        }
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        foreach ($id in $BuildId) {
            $action = @{
                status = 'Cancelling'
            }
            $json = $action | ConvertTo-Json
            Write-Verbose -Message 'Payload:'
            Write-Verbose -Message $json
            $removedBuild = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Patch `
                -Project $Project `
                -Endpoint "build/builds/$id" `
                -Body $json `
                -NoRetry:$NoRetry
            Write-Verbose -Message 'The following build was cancelled:'
            Write-Verbose -Message ( $removedBuild | Format-Table | Out-String )
            if ($env:BUILD_BUILDID) {
                $tag = "Stopped via AzDOCmd by $env:BUILD_DEFINITIONNAME - $env:BUILD_BUILDID"
            }
            elseif ($env:BUILD_REQUESTEDFOREMAIL) {
                $tag = "Stopped via AzDOCmd by $env:BUILD_REQUESTEDFOREMAIL"
            }
            else {
                $tag = 'Stopped via AzDOCmd'
            }
            $null = $removedBuild | Add-AzDOPipelineRunTag `
                -Tag $tag `
                -CollectionUri $CollectionUri `
                -Pat $Pat `
                -NoRetry:$NoRetry
            if ($PassThru) {
                $removedBuild | Get-AzDOPipelineRun -CollectionUri $CollectionUri -Pat $Pat -NoRetry:$NoRetry
            }
        }
    }
}
