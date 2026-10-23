Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/Public/pipelines/Watch-AzDOPipelineRun.ps1"
        . "$PSScriptRoot/../../../src/Public/pipelines/Get-AzDOPipelineRun.ps1"
        . "$PSScriptRoot/../../../src/Public/pipelines/Get-AzDOPipeline.ps1"
        . "$PSScriptRoot/../../../src/Public/pipelines/Start-AzDOPipelineRun.ps1"

        Mock Clear-Host

        Mock Write-Progress

        Mock Write-Host `
            -ParameterFilter { $Object -match '\n\n\n\n\n' } `
            -MockWith {
                Write-Information -MessageData "`n" -InformationAction 'Continue'
            }
    }

    It 'should monitor builds until completion' {
        $buildWatch = Get-AzDOPipeline -Name 'PipelineTest-Short' -Project Tools |
            Start-AzDOPipelineRun -Branch main |
            Watch-AzDOPipelineRun -PollingInterval 2 -Project Tools
        $buildWatch | Out-String | Should -Match 'completed'
    }

    It 'should monitor builds across projects' {
        $builds = Get-AzDOPipeline -Name 'PipelineTest-Short' -Project Tools, MyProject |
            Start-AzDOPipelineRun -Branch main
        $buildWatch = Watch-AzDOPipelineRun -BuildId $builds.id -PollingInterval 2 -Project Tools, MyProject
        $buildWatch | Should -HaveCount 2
    }
}
