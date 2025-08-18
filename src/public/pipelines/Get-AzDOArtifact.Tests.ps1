Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name PSAzDevOps -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../PSAzDevOps.psm1" -Force
    }

    It 'should get an artifact using parameters' {
        $build = Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
            Get-AzDOPipelineRunList -MaxRuns 1 -Completed
        Get-AzDOArtifact -BuildId $build.id -List |
            Should -Not -BeNullOrEmpty
    }

    It 'should get part of an artifact using SubPath' {
        $build = Get-AzDOPipeline -Name 'TestPipeline-Artifacts' -Project 'TestProject' |
            Get-AzDOPipelineRunList -MaxRuns 1 -Succeeded
        Get-AzDOArtifact -BuildId $build.id -ArtifactName 'Artifact1' -SubPath 's' -Destination $TestDrive
        "$TestDrive/s.zip" | Should -Exist
        { Expand-Archive -Path "$TestDrive/s.zip" -Destination $TestDrive } | Should -Not -Throw
        ( Get-ChildItem -Path "$TestDrive/Artifact1" ).Name | Should -Not -Contain 'TestResults'
    }

    Context 'MyProject' {
        BeforeAll {
            $script:existingProject = $env:SYSTEM_TEAMPROJECT
            $env:SYSTEM_TEAMPROJECT = 'MyProject'
        }

        It 'should get an artifact with pipeline input' {
            Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -List |
                Should -Not -BeNullOrEmpty
        }

        It 'should get an artifact by name' {
            $artifacts = Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -Name 'TestArtifact' -List
            $artifacts.Name -join ',' | Should -HaveCount 1
            $artifacts.Name -join ',' | Should -Not -Match 'Coverage'
        }

        It 'should download all artifacts by default' {
            New-Item -Path "$TestDrive/TestArtifacts" -ItemType Directory -Force
            Get-AzDOPipeline -Name 'TestPipeline-Artifacts' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -Destination "$TestDrive/TestArtifacts"
            Get-ChildItem -Path "$TestDrive/TestArtifacts" |
                Should -HaveCount 2
        }

        It 'should warn if no artifacts are found in the build' {
            $artifacts = Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -List
            $artifacts | Should -BeNullOrEmpty
            $warning = Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -List 3>&1
            $warning | Should -Match 'No artifacts found'
        }

        It 'should warn if no artifacts matching the name are found' {
            $artifacts = Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -Name 'NonExistentArtifact' -List
            $artifacts | Should -BeNullOrEmpty
            $warning = Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -Name 'NonExistentArtifact' -List 3>&1
            $warning | Should -Match "No artifacts found matching 'Artifact_that_doesnt_exist'"
        }

        It 'should only return the artifacts as objects' {
            New-Item -Path "$TestDrive/artifact-download" -ItemType Directory -Force
            Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                Get-AzDOArtifact -Name 'TestArtifact' -Destination "$TestDrive/artifact-download" |
                Should -HaveCount 1
        }

        It 'should still output the destination directory without returning it' {
            New-Item -Path "$TestDrive/artifact-download" -ItemType Directory -Force
            (
                Get-AzDOPipeline -Name 'TestPipeline' -Project 'TestProject' |
                    Get-AzDOPipelineRunList -MaxRuns 1 -Completed |
                    Get-AzDOArtifact -Name 'TestArtifact' -Destination "$TestDrive/artifact-download" 6>&1
            ) -join ', ' | Should -Match (
                [Regex]::Escape(( Join-Path -Path $TestDrive -ChildPath 'artifact-download' ))
            )
        }

        AfterAll {
            $env:SYSTEM_TEAMPROJECT = $script:existingProject
        }
    }
}
