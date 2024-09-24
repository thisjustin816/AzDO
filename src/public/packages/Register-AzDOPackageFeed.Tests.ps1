Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
        Mock Set-EnvironmentVariable { }
    }

    It 'should register a new Azure Artifacts Feed' {
        $feedName = "TestFeed-Reg-AzDOPackageFeed-$(( New-Guid ).Guid)"
        New-AzDOPackageFeed -Name $feedName -Project Tools | Register-AzDOPackageFeed
        ( Get-PackageSource ).Name | Should -Contain $feedName
        Get-PackageSource -Name $feedName -ErrorAction SilentlyContinue |
            Unregister-PackageSource -Force -ErrorAction SilentlyContinue
        Remove-AzDOPackageFeed -Name $feedName -Project Tools -Force
    }

    Context 'v2 and v3 Feeds' {
        It 'should register a new Azure Artifacts v<Version> Feed by name' -TestCases @(
            @{ Version = 2 }
            @{ Version = 3 }
        ) {
            param ($Version)
            $feedName = "TestFeed-Reg-AzDOPackageFeed-$(( New-Guid ).Guid)"
            New-AzDOPackageFeed -Name $feedName
            Register-AzDOPackageFeed -Name $feedName -FeedVersion $Version
            ( Get-PackageSource ).Name | Should -Contain $feedName
            Get-PackageSource -Name $feedName -ErrorAction SilentlyContinue |
                Unregister-PackageSource -Force -ErrorAction SilentlyContinue
            Remove-AzDOPackageFeed -Name $feedName -Force
        }
    }
}
