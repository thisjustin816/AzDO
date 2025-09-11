Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot\..\AzDOCmd.psm1" -Force

        # Dot source the function under test
        . "$PSScriptRoot\Get-AzDOApiProjectName.ps1"
    }

    Context 'when processing string project names' {
        It 'should return string project names unchanged' {
            $projects = @('MyProject', 'Tools')
            $result = $projects | Get-AzDOApiProjectName
            $result | Should -BeExactly $projects
        }

        It 'should handle a single string project name' {
            $project = 'MyProject'
            $result = $project | Get-AzDOApiProjectName
            $result | Should -BeExactly 'MyProject'
        }

        It 'should handle null or empty input' {
            $result = $null | Get-AzDOApiProjectName
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when processing project objects' {
        It 'should extract name property from project objects' {
            $projectObjects = @(
                [PSCustomObject]@{ name = 'MyProject'; id = 'proj1' }
                [PSCustomObject]@{ name = 'Tools'; id = 'proj2' }
            )
            $result = $projectObjects | Get-AzDOApiProjectName
            $result | Should -HaveCount 2
            $result[0] | Should -BeExactly 'MyProject'
            $result[1] | Should -BeExactly 'Tools'
        }

        It 'should extract id property when name is not available' {
            $projectObjects = @(
                [PSCustomObject]@{ id = 'proj1' }
                [PSCustomObject]@{ id = 'proj2' }
            )
            $result = $projectObjects | Get-AzDOApiProjectName
            $result | Should -HaveCount 2
            $result[0] | Should -BeExactly 'proj1'
            $result[1] | Should -BeExactly 'proj2'
        }

        It 'should prefer name over id when both are available' {
            $projectObject = [PSCustomObject]@{ name = 'MyProject'; id = 'proj1' }
            $result = $projectObject | Get-AzDOApiProjectName
            $result | Should -BeExactly 'MyProject'
        }
    }
}