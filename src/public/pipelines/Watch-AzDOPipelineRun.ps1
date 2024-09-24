<#
.SYNOPSIS
Reports build status until completion.

.DESCRIPTION
Reports build status until completion, either by build ID or user email.

.PARAMETER BuildId
ID of the pipeline runs to watch.

.PARAMETER User
Email address of the user the pipeline runs are requested for.

.PARAMETER Project
The Azure DevOps project(s) where the pipeline runs are running. Defaults to $env:SYSTEM_TEAMPROJECT to work with Azure
Pipelines.

.PARAMETER PollingInterval
Time period in seconds in between getting build information. Defaults to 15 seconds.

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to read pipeline runs.

.EXAMPLE
Watch-UserBuild -User myorg@dev.azure.com -Project MyProject

.EXAMPLE
Get-AzDOPipeline -Name 'PipelineTest-Short' -Project Tools |
    Start-AzDOPipelineRun -Branch main |
    Watch-AzDOPipelineRun

.NOTES
N/A
#>

function Watch-AzDOPipelineRun {
    [CmdletBinding(DefaultParameterSetName = 'User')]
    param (
        [Parameter(ParameterSetName = 'BuildId', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('id')]
        [Int[]]$BuildId,
        [Parameter(ParameterSetName = 'User')]
        [String[]]$User = @($env:BUILD_REQUESTEDFOREMAIL),
        [String]$PollingInterval = 15,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object[]]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        <#
        .SYNOPSIS
        Convert raw JSON into PowerShell readable object.
        #>
        function ConvertTo-PipelineRunObject {
            param (
                [System.Object]$JsonObject
            )
            $userBuild = [PSCustomObject]@{
                BuildId      = $JsonObject.id
                PipelineName = $JsonObject.definition.name
                Project      = $JsonObject.project.name
                Status       = $JsonObject.status
                Result       = $JsonObject.result
                BuildName    = $JsonObject.buildNumber
                Reason       = $JsonObject.reason
                Tags         = ($JsonObject.tags -join ', ')
                Url          = $JsonObject._links.web.href
            }
            # Set default output to table. From:
            # https://learn-powershell.net/2013/08/03
            # /quick-hits-set-the-default-property-display-in-powershell-on-custom-objects/
            $userBuild.PSObject.TypeNames.Insert(0, 'Build')
            $defaultDisplaySet = 'BuildId', 'PipelineName', 'Status', 'Result'
            $defaultDisplayPropertySet = New-Object `
                -TypeName System.Management.Automation.PSPropertySet(
                'DefaultDisplayPropertySet', [string[]]$defaultDisplaySet
            )
            $PSStandardMembers = (
                [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
            )
            $userBuild |
                Add-Member `
                    -MemberType MemberSet `
                    -Name PSStandardMembers `
                    -Value $PSStandardMembers
            $userBuild
        }
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        $allBuildIds = @()
        $activity = 'Monitoring pipeline runs '
        $activity += if ($BuildId) {
            $BuildId -join ', '
        }
        else {
            "for $($User -join ', ')"
        }
        $activity += " in $($Project -join ', ')"
        $writeProgressArgs = @{
            Activity         = $activity
            CurrentOperation = (
                'Run watch will end when all current pipeline runs are completed. Press Ctrl + C to exit.'
            )
        }
        $firstRun = $true
        $finalRun = $null
        do {
            if ($firstRun) {
                $seconds = 0
            }
            else {
                $seconds = $PollingInterval
            }
            $writeProgressArgs['Status'] = "Waiting $seconds seconds to poll pipeline runs..."
            Write-Progress @writeProgressArgs
            for ($i = 1; $i -le $seconds; $i++) {
                Start-Sleep -Seconds 1
                Write-Progress @writeProgressArgs -PercentComplete (($i / $seconds) * 100)
            }
            Write-Progress @writeProgressArgs -Completed

            $builds = @()
            $writeProgressArgs['Status'] = 'Finding pipeline runs...'
            Write-Progress @writeProgressArgs
            $getBuild = @{
                Project       = $Project
                CollectionUri = $CollectionUri
                Pat           = $Pat
                WarningAction = 'SilentlyContinue'
            }
            $builds += if ($BuildId) {
                Get-AzDOPipelineRun -BuildId $BuildId @getBuild
            }
            else {
                Get-AzDOPipelineRun -User $User -Status @('inProgress', 'notStarted') @getBuild
            }

            $writeProgressArgs['Status'] = 'Getting all queued pipeline runs...'
            Write-Progress @writeProgressArgs
            $allBuildIds += foreach ($id in $builds.id) {
                $id
            }
            $allBuildIds = @( $allBuildIds | Sort-Object -Unique -Descending )
            if ($allBuildIds) {
                do {
                    $allBuilds = Get-AzDOPipelineRun -BuildId $allBuildIds @getBuild
                } while (!$allBuilds)
                $displayBuilds = @()
                $displayBuilds += foreach ($build in $allBuilds) {
                    if ($build.status -ne 'completed') {
                        ConvertTo-PipelineRunObject -JsonObject $build
                    }
                }
                $displayBuilds += foreach ($build in $allBuilds) {
                    if ($build.status -eq 'completed') {
                        ConvertTo-PipelineRunObject -JsonObject $build
                    }
                }
                Write-Progress @writeProgressArgs -Completed
                Clear-Host
                $inProgress = $allBuilds | Where-Object -Property status -Match '(inProgress|notStarted)'

                # Sometimes triggered builds take a few seconds to start,
                # so we need to double check if no builds are found and it isn't
                # the first run.
                if ($finalRun -eq $true) {
                    $finalRun = $false
                }
                if ($inProgress) {
                    $finalRun = $null
                    if (( Get-PSVersion ).Major -lt 7) {
                        Write-Host -Object "`n`n`n`n`n`n`n`n`n"
                    }
                }
                elseif (!$firstRun -and $finalRun -ne $false) {
                    $finalRun = $true
                }
                $firstRun = $false

                $consoleHeight = $Host.UI.RawUI.WindowSize.Height
                $buildsToDisplay = [Math]::max(0, $consoleHeight - 13)
                Write-Host -Object (
                    $displayBuilds |
                        Select-Object -Property * -First $buildsToDisplay |
                        Format-Table |
                        Out-String
                ).Trim()
                if ($displayBuilds.Count -ge $buildsToDisplay) {
                    Write-Host `
                        -Object " ......`tincrease the console height to view more pipeline runs." `
                        -ForegroundColor Gray
                }
            }
            Write-Verbose -Message '#############################################################################'
            Write-Verbose -Message (
                "In progress: $( ConvertTo-PipelineRunObject -JsonObject $inProgress -ErrorAction SilentlyContinue )"
            )
            Write-Verbose -Message "Final run: $finalRun"
            Write-Verbose -Message "Should loop again: $(($inProgress -or $finalRun))"
            Write-Verbose -Message '#############################################################################'
        } while ($inProgress -or $finalRun)
        $displayBuilds
    }
}
