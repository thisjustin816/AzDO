Describe 'Tests' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDO.psm1" -Force
    }

    It 'should get info for a repo' {
        $repo = Get-AzDORepository -Name AzDO -Project MyProject
        $repo.name | Should -Be AzDO
    }
}