Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should return builds in order of id' {
        $builds = Get-BuildPipeline -Name PipelineTest -Project Tools |
            Get-AzDOPipelineRunList -MaxBuilds 10 -IncludePr
        $builds.id | Should -BeExactly ( $builds.id | Sort-Object -Descending )
    }

    It 'should exclude PR builds if specified' {
        $fiftyBuilds = Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -MaxBuilds 10
        ( $fiftyBuilds | Select-Object -ExpandProperty reason ) -join ',' |
            Should -Not -Match 'pullRequest'
        $fiftyBuilds.Count | Should -BeLessOrEqual 10
    }

    It 'should still get a build if MaxBuilds is 1 and most recent is a PR' {
        $nonPrBuild = Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -MaxBuilds 1
        $nonPrBuild | Should -HaveCount 1
        $nonPrBuild.reason | Should -Not -Be 'pullRequest'
    }

    It 'should only get in progress builds if specified' {
        Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -InProgress -IncludePr |
            ForEach-Object -Process {
                ('inProgress', 'notStarted') | Should -Contain $_.status
            }
    }

    It 'should only get completed builds if specified' {
        Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -MaxBuilds 25 -HasResult -IncludePr |
            ForEach-Object -Process {
                $_.status | Should -Match 'completed'
            }
    }

    It 'should only get succeeded builds if specified' {
        Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -MaxBuilds 25 -Succeeded -IncludePr |
            ForEach-Object -Process {
                $_.result | Should -Match 'succeeded'
            }
    }

    It 'should only return builds in the past <_> days' -TestCases @(1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21) {
        $historyInDays = $_
        $threshold = [DateTime]::Today.AddDays(-$historyInDays).ToUniversalTime()
        Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -HistoryInDays $historyInDays |
            ForEach-Object -Process {
                if (( $_.finishTime | Get-Date ).ToUniversalTime() -lt $threshold) {
                    Write-Host -Object "Build outside threshold: $($_.id)"
                }
                ( $_.finishTime | Get-Date ).ToUniversalTime() | Should -BeGreaterThan $threshold
            }
    }

    It 'should give a warning if no builds were found' {
        Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -Branch non-existent-branch |
            Should -HaveCount 0
        Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -Branch non-existent-branch 3>&1 |
            Should -Match 'No builds found'
    }

    It 'should only return builds from a given branch' {
        Get-BuildPipeline -Name AzDOCmd -Project Tools |
            Get-AzDOPipelineRunList -MaxBuilds 50 -IncludePr -Branch integration |
            ForEach-Object -Process {
                $_.sourceBranch | Should -BeExactly 'refs/heads/integration'
            }
    }
}
