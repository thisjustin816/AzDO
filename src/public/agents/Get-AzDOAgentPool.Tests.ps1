Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDO.psm1" -Force
    }

    It 'should return all agent pools by default' {
        ( Get-AzDOAgentPool ).Count | Should -BeGreaterThan 1
    }

    It 'should return one pool with the specified name' {
        $pool = Get-AzDOAgentPool -Name 'Azure Pipelines'
        $pool.id | Should -BeExactly 10
    }

    It 'should be able to return multiple named pools' {
        $pools = Get-AzDOAgentPool -Name @('Azure Pipelines', 'Azure Pipelines')
        $pools.Count | Should -BeExactly 2
        $pools.id | Should -Contain 10
        $pools.id | Should -Contain 48
    }
}
