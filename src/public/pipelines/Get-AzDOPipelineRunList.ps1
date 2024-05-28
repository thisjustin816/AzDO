<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER BuildPipeline
A build pipeline object returned from Get-BuildPipeline.

.PARAMETER Branch
Only return builds from a given branch.

.PARAMETER MaxBuilds
The number of most recent builds to get. Defaults to 10.

.PARAMETER HistoryInDays
Only return builds from this number of days in the past (including today).

.PARAMETER IncludePr
Include PR builds in the list (disabled by default).

.PARAMETER HasResult
Only return builds that have failed, succeeded or partially succeeded.

.PARAMETER Succeeded
Include only completed and succeeded builds.

.PARAMETER Pat
Personal access token authorized to administer builds. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
Get-BuildPipeline -Name utils-integration-checkin -Project MyProject | Get-AzDOPipelineRunList -MaxBuilds 3

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/list
#>
function Get-AzDOPipelineRunList {
    [CmdletBinding(DefaultParameterSetName = 'Max')]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.Object[]]$BuildPipeline,
        [String]$Branch,
        [Parameter(ParameterSetName = 'Max')]
        [Int]$MaxBuilds,
        [Parameter(ParameterSetName = 'Date')]
        [Int]$HistoryInDays,
        [Switch]$IncludePr,
        [Switch]$InProgress,
        [Switch]$HasResult,
        [Alias('Completed')]
        [Switch]$Succeeded,
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
            do {
                $params = @(
                    "definitions=$($pipeline.id -join ',')"
                )

                if ($HistoryInDays) {
                    $minTime = [DateTime]::Today.AddDays(-$HistoryInDays).ToUniversalTime() |
                        Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.ffK'
                    $params += @(
                        "minTime=$minTime"
                    )
                }

                $buildReasons = (
                    'reasonFilter=batchedCI,buildCompletion,resourceTrigger,individualCI,manual,schedule,triggered'
                )
                if ($IncludePr) {
                    $buildReasons += ',pullRequest'
                }
                $params += $buildReasons

                if ($InProgress) {
                    $params += @(
                        'statusFilter=inProgress,NotStarted'
                    )
                }
                elseif ($HasResult) {
                    $params += @(
                        'statusFilter=completed',
                        'resultFilter=canceled,failed,partiallySucceeded,succeeded'
                    )
                }
                elseif ($Succeeded) {
                    $params += @(
                        'statusFilter=completed',
                        'resultFilter=succeeded'
                    )
                }

                if ($MaxBuilds -and !$HistoryInDays) {
                    # Add the amount of erroneous PR builds included in the result and had to be removed
                    if ($null -ne $finalBuildInfo) {
                        $addMore = $top - $finalBuildInfo.Count
                    }
                    else {
                        $addMore = 0
                    }
                    $top = $MaxBuilds + $addMore
                    $params += @(
                        "`$top=$top"
                    )
                }

                if ($Branch) {
                    $params += "branchName=refs/heads/$Branch"
                }


                $buildInfo = @()
                $buildInfo += Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -Project $pipeline.project.name `
                    -Endpoint 'build/builds' `
                    -Params $params `
                    -NoRetry:$NoRetry |
                    Sort-Object -Descending -Property id
                if ($buildInfo -and !$IncludePr) {
                    # The reasonFilter parameter seems to be broken so we
                    # need to manually filter pullRequest builds
                    $finalBuildInfo = @()
                    $finalBuildInfo += $buildInfo | Where-Object -Property reason -NE 'pullRequest'
                }
                elseif ($buildInfo) {
                    $finalBuildInfo = $buildInfo
                }
                # Since the pullRequest reason filter isn't working, it's possible that
                # MaxBuilds won't find a single build with the specified parameter, so we
                # need to loop through until it's met.
            } while (
                $buildInfo -and
                $finalBuildInfo.Count -lt $MaxBuilds -and
                ($top -lt 100 -or $top -le ($MaxBuilds * 2))
            )
            if ($finalBuildInfo) {
                $finalBuildInfo
            }
            else {
                Write-Warning -Message (
                    "No builds found in the $($pipeline.name) pipeline with " +
                    "the specified parameters:`n`t" +
                    ($params -join "`n`t")
                )
            }
        }
    }
}
