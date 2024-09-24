Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    BeforeEach {
        $script:testFeed = New-AzDOPackageFeed -Name "TestFeed-Retention-$(( New-Guid ).Guid)"
    }

    AfterEach {
        $script:testFeed | Remove-AzDOPackageFeed -Force
    }

    It 'should remove a set policy' {
        $script:testFeed | Set-AzDOPackageFeedRetention -Days 42 -Force
        $script:testFeed | Remove-AzDOPackageFeedRetention -Force
        $script:testFeed | Get-AzDOPackageFeedRetention | Should -Be 'null'
    }
}
