Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name PSAzDevOps -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../PSAzDevOps.psm1" -Force
    }

    It 'should remove package feeds successfully' {
        New-AzDOPackageFeed -Name "TestFeed-Rem-AzDOPackageFeed-$(( New-Guid ).Guid)"
        Get-AzDOPackageFeed |
            Where-Object -Property name -Match 'TestFeed-.*' |
            Remove-AzDOPackageFeed -Force
        Get-AzDOPackageFeed |
            Where-Object -Property name -Match 'TestFeed-.*' |
            Should -BeNullOrEmpty
    }

    AfterAll {
        Get-AzDOPackageFeed |
            Where-Object -Property name -Match 'TestFeed-.*' |
            Remove-AzDOPackageFeed -Force
    }
}
