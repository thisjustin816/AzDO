Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should be able to start a build from a given pipeline with the same name as the repo' {
        $pipeline = Get-AzDOPipeline -Name PipelineTest -Project Tools
        $queuedBuild = $pipeline |
            Start-AzDOPipelineRun -Branch main -NoRetry
        $queuedBuild.definition.name | Should -Be PipelineTest
        $queuedBuild.status | Should -Be notStarted
        do {
            Start-Sleep 1
            $startedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
            Write-Host -Object "Waiting for $($startedBuild.id) to start: $($startedBuild.status)"
        } while ($startedBuild.status -eq 'notStarted')
        $startedBuild.status | Should -Be inProgress
        $queuedBuild | Stop-AzDOPipelineRun
    }

    It 'should be able to start a build from a given pipeline with a different name than the repo' {
        $queuedBuild = Get-AzDOPipeline -Name TestPipeline -Project Tools |
            Start-AzDOPipelineRun -Branch main
        $queuedBuild.definition.name | Should -Be TestPipeline
        $queuedBuild.status | Should -Be notStarted
        do {
            Start-Sleep 1
            $startedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
            Write-Host -Object "Waiting for $($startedBuild.id) to start: $($startedBuild.status)"
        } while ($startedBuild.status -eq 'notStarted')
        $startedBuild.status | Should -Be inProgress
        $queuedBuild | Stop-AzDOPipelineRun
    }

    It 'should be able to start a build using the pipelines default branch' {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun
        $queuedBuild.definition.name | Should -Be PipelineTest
        $queuedBuild.status | Should -Be notStarted
        $queuedBuild.sourceBranch | Should -Be 'refs/heads/main'
        Start-Sleep 1
        $queuedBuild | Stop-AzDOPipelineRun
    }

    It 'should be able to start a build using a specific branch' {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun -Branch notmain
        $queuedBuild.definition.name | Should -Be PipelineTest
        $queuedBuild.status | Should -Be notStarted
        $queuedBuild.sourceBranch | Should -Be 'refs/heads/notmain'
        Start-Sleep 1
        $queuedBuild | Stop-AzDOPipelineRun
    }

    It 'should be able to start builds on multiple branches at once' {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun -Branch main, notmain
        $queuedBuild.definition.name | Should -Contain PipelineTest
        $queuedBuild.status | Should -Contain notStarted
        $queuedBuild.sourceBranch | Should -Contain 'refs/heads/main'
        $queuedBuild.sourceBranch | Should -Contain 'refs/heads/notmain'
        Start-Sleep 1
        $queuedBuild | Stop-AzDOPipelineRun
    }

    It "should still be able to find the build's repo without a CI build" {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest-Manual -Project Tools |
            Start-AzDOPipelineRun
        $queuedBuild.definition.name | Should -Be PipelineTest-Manual
        $queuedBuild.status | Should -Be notStarted
        $queuedBuild.sourceBranch | Should -Be 'refs/heads/main'
        $queuedBuild.repository.name | Should -Be PipelineTest
        Start-Sleep 1
        $queuedBuild | Stop-AzDOPipelineRun
    }

    It 'should have a AzDOCmd tag on builds started from this function' {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest-Short -Project Tools |
            Start-AzDOPipelineRun -Branch main
        Start-Sleep 1
        $queuedBuild | Get-AzDOPipelineRunTag | Should -Match 'Started via AzDOCmd'
    }

    It 'should be able to set queue-time parameters' {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest-Short -Project Tools |
            Start-AzDOPipelineRun -Branch main -Parameter @{ testParam = 'testValue' }
        $queuedBuild.templateParameters.testParam | Should -Be 'testValue'
    }
}
