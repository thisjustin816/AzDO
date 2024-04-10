Describe 'Tests' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDO.psm1" -Force
    }

    It 'should return the named projects' {
        $projects = @( Get-AzDOProject -Name MyProject, MyProject )
        $projects | Should -HaveCount 2
        $projects.name | Should -Contain 'MyProject'
        $projects.name | Should -Contain 'MyProject'
    }

    It 'should return all projects in the collection if no name is specified' {
        $projects = @( Get-AzDOProject )
        $projects.Count | Should -BeGreaterThan 2
        $projects.name | Should -Contain 'MyProject'
        $projects.name | Should -Contain 'MyProject'
    }
}