Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    Context 'When getting builds in project: <_>' -ForEach (@('Tools'), @('MyProject', 'Tools')) {
        BeforeAll {
            $script:Project = $_
            $testBuild = Get-BuildPipeline -Name 'PipelineTest-Short' -Project $script:Project |
                Start-Build -Branch main
            $script:user = $testBuild.requestedFor.uniqueName | Sort-Object -Unique
            $script:buildId = $testBuild.id
        }

        It 'should return builds with the specified ID' {
            $idBuild = Get-AzDOPipelineRun -BuildId $script:buildId -Project $script:Project
            $idBuild | Should -HaveCount $script:Project.Count
            $idBuild.id | Should -BeExactly $script:buildId
        }

        It 'should return 3 builds per project by the user specified' {
            $script:userBuilds = Get-AzDOPipelineRun `
                -User $script:user `
                -Status completed `
                -Reason individualCI `
                -Result succeeded `
                -MaxBuilds 3 `
                -Project $script:Project
            $script:userBuilds | Should -HaveCount (3 * $script:Project.Count)
            $script:userBuilds.project.name | Sort-Object -Unique | Should -Be ( $script:Project | Sort-Object )

            foreach ($build in $script:userBuilds) {
                $build.status | Should -BeExactly completed
                $build.reason | Should -BeExactly individualCI
                $build.result | Should -BeExactly succeeded
            }
        }
    }

    It 'should return builds using multiple filters of the same type' {
        $script:userBuilds = Get-AzDOPipelineRun `
            -User $script:user `
            -Status (
                'completed',
                'inProgress',
                'notStarted'
            ) `
            -Reason (
                'batchedCI',
                'buildCompletion',
                'individualCI',
                'manual',
                'pullRequest',
                'resourceTrigger',
                'schedule',
                'scheduleForced',
                'triggered'
            ) `
            -MaxBuilds 100 `
            -Project 'Tools'

        foreach ($build in $script:userBuilds) {
            $build.status |
                Should -Match '(completed|inProgress|notStarted)'
            $build.reason |
                Should -Match (
                    '(batchedCI|buildCompletion|individualCI|manual|' + `
                        'pullRequest|resourceTrigger|schedule|scheduleForced|triggered)'
                )
            $build.result | Should -Match '(canceled|failed|partiallySucceeded|succeeded)'
        }
    }

    It 'should take a build object from the pipeline' {
        $inputBuild = Get-BuildPipeline -Name 'PipelineTest-Short' -Project Tools | Start-Build -Branch main
        $pipelineBuild = $inputBuild | Get-AzDOPipelineRun
        Compare-Object -ReferenceObject $inputBuild -DifferenceObject $pipelineBuild | Should -BeNullOrEmpty
    }

    It 'should give a warning when no builds are found for the specified ID' {
        Get-AzDOPipelineRun -BuildId '123' -Project Tools | Should -BeNullOrEmpty
        $idWarning = Get-AzDOPipelineRun -BuildId '123' -Project Tools 3>&1
        $idWarning | Should -Match 'Build 123 not found in Tools.'
    }

    It 'should give a warning when no user builds are found' {
        Get-AzDOPipelineRun `
            -User 'user@domain.com' `
            -Status completed `
            -Reason individualCI `
            -Result succeeded `
            -Project Tools |
            Should -BeNullOrEmpty
        $script:userWarning = Get-AzDOPipelineRun `
            -User 'user@domain.com' `
            -Status completed `
            -Reason individualCI `
            -Result succeeded `
            -Project Tools `
            3>&1
        $script:userWarning |
            Should -Match 'succeeded/completed/individualCI builds for user@domain.com not found.'
    }
}
