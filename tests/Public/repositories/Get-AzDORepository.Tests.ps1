Describe 'Tests' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        . "$PSScriptRoot/../../Import-TestModule.ps1"
    }

    It 'should get info for a repo' {
        $repo = Get-AzDORepository -Name AzDO -Project MyProject
        $repo.name | Should -Be AzDO
    }
}