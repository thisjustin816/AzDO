Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should create a new feed' {
        $feedName = "TestFeed-$(( New-Guid ).Guid)"
        ( New-AzDOPackageFeed -Name $feedName ).name | Should -Be $feedName
        Remove-AzDOPackageFeed -Name $feedName -Force -ErrorAction SilentlyContinue
    }

    It 'should create a new project-scoped feed' {
        $feedName = "TestFeed-$(( New-Guid ).Guid)"
        ( New-AzDOPackageFeed -Name $feedName -Project Tools ).name | Should -Be $feedName
        Remove-AzDOPackageFeed -Name $feedName -Project Tools -Force -ErrorAction SilentlyContinue
    }
}
