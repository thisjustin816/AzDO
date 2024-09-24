Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should get multiple tags from multiple builds' {
        $testPipeline = Get-AzDOPipeline -Name PipelineTest-Short -Project Tools
        $queuedBuilds = (
            ( $testPipeline | Start-AzDOPipelineRun ),
            ( $testPipeline | Start-AzDOPipelineRun )
        )
        $tags = 'addBuildTagTest1', 'addBuildTagTest2'
        $queuedBuilds | Add-AzDOPipelineRunTag -Tag $tags
        $buildTags = $queuedBuilds | Get-AzDOPipelineRunTag
        foreach ($tag in $tags) {
            $buildTags | Should -Contain $tag
            $buildTags | Where-Object { $_ -eq $tag } | Should -HaveCount 2
        }
    }
}
