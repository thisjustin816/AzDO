Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should remove tags from multiple builds with multiple IDs' {
        $testPipeline = Get-AzDOPipeline -Name PipelineTest-Short -Project Tools
        $queuedBuilds = (
            ( $testPipeline | Start-AzDOPipelineRun ),
            ( $testPipeline | Start-AzDOPipelineRun )
        )
        $tags = 'removeBuildTagTest1', 'removeBuildTagTest2', 'removeBuildTagTest3'
        $queuedBuilds | Add-AzDOPipelineRunTag -Tag $tags
        $removedTags = 'removeBuildTagTest1', 'removeBuildTagTest2'
        $queuedBuilds | Remove-AzDOPipelineRunTag -Tag $removedTags -Force
        foreach ($build in $queuedBuilds) {
            foreach ($tag in $removedTags) {
                $build | Get-AzDOPipelineRunTag | Should -Not -Contain $tag
            }
            $build | Get-AzDOPipelineRunTag | Should -Contain 'removeBuildTagTest3'
        }
    }

    It 'should remove all tags from a build if none are specified' {
        $testPipeline = Get-AzDOPipeline -Name PipelineTest-Short -Project Tools
        $queuedBuilds = (
            ( $testPipeline | Start-AzDOPipelineRun ),
            ( $testPipeline | Start-AzDOPipelineRun )
        )
        $tags = 'removeBuildTagTest1', 'removeBuildTagTest2', 'removeBuildTagTest3'
        $queuedBuilds | Add-AzDOPipelineRunTag -Tag $tags
        $queuedBuilds | Remove-AzDOPipelineRunTag -Force
        foreach ($build in $queuedBuilds) {
            foreach ($tag in $tags) {
                $build | Get-AzDOPipelineRunTag | Should -BeNullOrEmpty
            }
        }
    }
}
