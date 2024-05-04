Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should return the named projects' {
        $projects = @( Get-Project -Name MyProject, Tools )
        $projects | Should -HaveCount 2
        $projects.name | Should -Contain 'MyProject'
        $projects.name | Should -Contain 'Tools'
    }

    It 'should return all projects in the collection if no name is specified' {
        $projects = @( Get-Project )
        $projects.Count | Should -BeGreaterThan 2
        $projects.name | Should -Contain 'MyProject'
        $projects.name | Should -Contain 'Tools'
    }
}