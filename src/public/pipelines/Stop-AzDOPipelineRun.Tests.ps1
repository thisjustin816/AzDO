Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }
    It 'should stop a running build' {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun -Branch main
        do {
            Start-Sleep 1
            $startedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
        } while ($startedBuild.status -eq 'notStarted')
        $queuedBuild | Stop-AzDOPipelineRun
        do {
            Start-Sleep 1
            $stoppedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
        } while ($stoppedBuild.status -eq 'inProgress' -or $stoppedBuild.status -eq 'cancelling')
        $stoppedBuild.status | Should -Be completed
        $stoppedBuild.result | Should -Be canceled
    }

    It 'should return a build object if PassThru is used' {
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun -Branch main
        do {
            Start-Sleep 1
            $startedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
        } while ($startedBuild.status -eq 'notStarted')
        $stoppedBuild = $queuedBuild | Stop-AzDOPipelineRun -PassThru
        $stoppedBuild | Should -Not -BeNullOrEmpty
    }

    It 'should tag the cancelled build with the current build ID if available' {
        $actualDefinitionName = $env:BUILD_DEFINITIONNAME
        $actualBuildId = $env:BUILD_BUILDID
        $env:BUILD_DEFINITIONNAME = 'StopTest'
        $env:BUILD_BUILDID = '12345'
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun -Branch main
        do {
            Start-Sleep 1
            $startedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
        } while ($startedBuild.status -eq 'notStarted')
        $stoppedBuild = $queuedBuild | Stop-AzDOPipelineRun -PassThru
        $stoppedBuild.tags | Should -Contain 'Stopped via AzDOCmd by StopTest - 12345'
        $env:BUILD_DEFINITIONNAME = $actualDefinitionName
        $env:BUILD_BUILDID = $actualBuildId
    }

    It "should tag the cancelled build with the PSSiOps user's email if available" {
        $actualBuildId = $env:BUILD_BUILDID
        $actualEmail = $env:BUILD_REQUESTEDFOREMAIL
        $env:BUILD_BUILDID = $null
        $env:BUILD_REQUESTEDFOREMAIL = 'email@example.com'
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun -Branch main
        do {
            Start-Sleep 1
            $startedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
        } while ($startedBuild.status -eq 'notStarted')
        $stoppedBuild = $queuedBuild | Stop-AzDOPipelineRun -PassThru
        $stoppedBuild.tags | Should -Contain 'Stopped via AzDOCmd by email@example.com'
        $env:BUILD_BUILDID = $actualBuildId
        $env:BUILD_REQUESTEDFOREMAIL = $actualEmail
    }

    It 'should be tag the cancelled build with a generic message if no build ID or email is available' {
        $actualBuildId = $env:BUILD_BUILDID
        $actualEmail = $env:BUILD_REQUESTEDFOREMAIL
        $env:BUILD_BUILDID = $null
        $env:BUILD_REQUESTEDFOREMAIL = $null
        $queuedBuild = Get-AzDOPipeline -Name PipelineTest -Project Tools |
            Start-AzDOPipelineRun -Branch main
        do {
            Start-Sleep 1
            $startedBuild = Get-AzDOPipelineRun -BuildId $queuedBuild.id -Project Tools
        } while ($startedBuild.status -eq 'notStarted')
        $stoppedBuild = $queuedBuild | Stop-AzDOPipelineRun -PassThru
        $stoppedBuild.tags | Should -Contain 'Stopped via AzDOCmd'
        $env:BUILD_BUILDID = $actualBuildId
        $env:BUILD_REQUESTEDFOREMAIL = $actualEmail
    }
}
