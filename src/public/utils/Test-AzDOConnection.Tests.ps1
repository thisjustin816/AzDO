Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDO.psm1" -Force
    }

    It 'should return an object with permissions settings' {
        $permissions = Test-AzDOConnection
        $permissions | Should -Not -BeNullOrEmpty
        $permissions.Authorized | Should -Not -Contain $false
    }

    It 'should output an error but not throw if something is not authorized' {
        {
            Test-AzDOConnection -Pat thisisnotapat -NoRetry -ErrorAction 'Continue'
        } | Should -Not -Throw
    }

    It 'should throw the number of unauthorized permissions if specified' {
        { Test-AzDOConnection -Pat thisisnotapat -NoRetry -ErrorAction Stop } |
            Should -Throw 'Not authorized for 6/6 permissions!'
    }
}