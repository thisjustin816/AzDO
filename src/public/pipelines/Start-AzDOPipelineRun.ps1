<#
.SYNOPSIS
Queues a build for the specified pipeline.

.DESCRIPTION
Queues a build for the specified pipeline.

.PARAMETER BuildPipeline
A build pipeline object returned from Get-AzDOPipeline.

.PARAMETER Branch
The branch to queue the build for.

.PARAMETER Parameter
A hash table of queue-time parameters to use when starting the build.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[orgranization]).

.PARAMETER Pat
Personal access token authorized to administer builds. Defaults to $env:SYSTEM_ACCESSTOKEN for use in
AzurePipelines.

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/run-pipeline

.EXAMPLE
Get-AzDOPipeline -Name utils-integration-checkin | Start-AzDOPipelineRun

.EXAMPLE
Get-AzDOPipeline -Name utils-int-karl-checkin | Start-AzDOPipelineRun -Parameter 'buildConfiguration:Release '

.Example
Get-AzDOPipeline -Name MxProduct-int-karl-checkin -Project MyProject |
    Start-AzDOPipelineRun -Branch int-karl -Parameter @{ buildConfiguration = 'Release ' }

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Start-AzDOPipelineRun {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.Object[]]$BuildPipeline,
        [String[]]$Branch,
        [System.Object]$Parameter,
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '6.1'
        }
    }

    process {
        foreach ($pipeline in $BuildPipeline) {
            $latestBuild = $pipeline | Get-AzDOPipelineRunList `
                -MaxBuilds 1 `
                -Succeeded `
                -CollectionUri $CollectionUri `
                -Pat $Pat `
                -NoRetry:$NoRetry
            if (!$latestBuild) {
                $latestBuild = $pipeline | Get-AzDOPipelineRunList `
                    -MaxBuilds 1 `
                    -IncludePr `
                    -CollectionUri $CollectionUri `
                    -Pat $Pat `
                    -NoRetry:$NoRetry
            }
            if (!$Branch) {
                $Branch = @(
                    Get-AzDORepository `
                        -Name $latestBuild.repository.name `
                        -NoRetry:$NoRetry `
                        -Project $latestBuild.project.name `
                        -CollectionUri $CollectionUri `
                        -Pat $Pat |
                        Select-Object -ExpandProperty 'defaultBranch' |
                        ForEach-Object -Process {
                            $_.Replace('refs/heads/', '')
                        }
                )
            }
            foreach ($ref in $Branch) {
                $body = @{
                    resources          = @{
                        repositories = @{
                            self = @{
                                refName = "refs/heads/$ref"
                            }
                        }
                    }
                    templateParameters = $Parameter
                } | ConvertTo-Json -Depth 6 -Compress
                if ($PSCmdlet.ShouldProcess("$($pipeline.name)", "Queue $ref branch")) {
                    $newRun = Invoke-AzDORestApiMethod `
                        @script:AzApiHeaders `
                        -Method 'Post' `
                        -Project "$($pipeline.project.name)" `
                        -Endpoint "pipelines/$($pipeline.id)/runs" `
                        -Body $body `
                        -NoRetry:$NoRetry
                    if ($env:BUILD_BUILDID) {
                        $tag = "Started via AzDOCmd by $env:BUILD_DEFINITIONNAME - $env:BUILD_BUILDID"
                    }
                    elseif ($env:BUILD_REQUESTEDFOREMAIL) {
                        $tag = "Started via AzDOCmd by $env:BUILD_REQUESTEDFOREMAIL"
                    }
                    else {
                        $tag = 'Started via AzDOCmd'
                    }
                    $newBuild = Get-AzDOPipelineRun `
                        -BuildId $newRun.id `
                        -Project $pipeline.project.name `
                        -CollectionUri $CollectionUri `
                        -Pat $Pat `
                        -NoRetry:$NoRetry
                    $null = $newBuild | Add-AzDOPipelineRunTag `
                        -Tag $tag `
                        -CollectionUri $CollectionUri `
                        -Pat $Pat `
                        -NoRetry:$NoRetry
                    $newBuild | Get-AzDOPipelineRun `
                        -CollectionUri $CollectionUri `
                        -Pat $Pat `
                        -NoRetry:$NoRetry
                }
            }
        }
    }
}
