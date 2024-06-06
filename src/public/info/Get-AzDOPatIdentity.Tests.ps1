Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should return an identity object' {
        ( Get-AzDOPatIdentity ).authorizedUser.providerDisplayName |
            Should -Not -BeNullOrEmpty
    }

    It 'should warn and not throw if identity not found' {
        { Get-AzDOPatIdentity -Pat 123456 -NoRetry } | Should -Not -Throw
        ( Get-AzDOPatIdentity -Pat 123456 -NoRetry 3>&1 ) -join ', ' |
            Should -Match 'No valid identity found'
    }
}