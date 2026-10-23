Describe 'Feed creation confirmation' -Tag 'Unit' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/Public/packages/New-AzDOPackageFeed.ps1"
        . "$PSScriptRoot/../../../src/Public/utils/Initialize-AzDORestApi.ps1"
        . "$PSScriptRoot/../../../src/Public/utils/Invoke-AzDORestApiMethod.ps1"
    }

    It 'does not call the API or decorate a missing result under WhatIf' {
        Mock Initialize-AzDORestApi { @{} }
        Mock Invoke-AzDORestApiMethod { $null }
        New-AzDOPackageFeed -Name Fixture -CollectionUri 'https://dev.azure.com/fixture' `
            -Pat fixture -WhatIf -ErrorAction Stop | Should -BeNullOrEmpty
        Should -Invoke Invoke-AzDORestApiMethod -Times 0
    }
}
Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        . "$PSScriptRoot/../../Import-TestModule.ps1"
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
