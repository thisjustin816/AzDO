Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
        $Script:testPipeline = Get-AzDOPipeline -Name PipelineTest-Short -Project Tools
    }

    It 'should tag a build with a single tag' {
        $queuedBuild = $Script:testPipeline | Start-AzDOPipelineRun
        $queuedBuild | Add-AzDOPipelineRunTag -Tag 'addBuildTagTest1'
        $queuedBuild | Get-AzDOPipelineRunTag | Should -Contain 'addBuildTagTest1'
    }

    It 'should tag multiple builds with multiple IDs' {
        $queuedBuilds = (
            ( $Script:testPipeline | Start-AzDOPipelineRun ),
            ( $Script:testPipeline | Start-AzDOPipelineRun )
        )
        $tags = 'addBuildTagTest1', 'addBuildTagTest2'
        $queuedBuilds | Add-AzDOPipelineRunTag -Tag $tags
        foreach ($build in $queuedBuilds) {
            $buildTags = $build | Get-AzDOPipelineRunTag
            foreach ($tag in $tags) {
                $buildTags | Should -Contain $tag
            }
        }
    }

    It 'should tag a build with a single tag containing spaces and -' {
        $queuedBuild = $Script:testPipeline | Start-AzDOPipelineRun
        $queuedBuild | Add-AzDOPipelineRunTag -Tag 'add Build Tag Test-1'
        $queuedBuild | Get-AzDOPipelineRunTag | Should -Contain 'add Build Tag Test-1'
    }

    It 'should tag multiple builds with multiple IDs containing spaces and -' {
        $queuedBuilds = (
            ( $Script:testPipeline | Start-AzDOPipelineRun ),
            ( $Script:testPipeline | Start-AzDOPipelineRun )
        )
        $tags = 'add Build Tag Test-1', 'add Build Tag Test-2'
        $queuedBuilds | Add-AzDOPipelineRunTag -Tag $tags
        foreach ($build in $queuedBuilds) {
            $buildTags = $build | Get-AzDOPipelineRunTag
            foreach ($tag in $tags) {
                $buildTags | Should -Contain $tag
            }
        }
    }
}
