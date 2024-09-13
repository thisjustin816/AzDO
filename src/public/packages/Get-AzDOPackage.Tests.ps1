Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name PSAzDevOps -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../PSAzDevOps.psm1" -Force
    }

    It 'should be able to get a package' {
        Get-AzDOPackage -Feed MyFeed | Select-Object name | Should -Not -BeNullOrEmpty
    }

    It 'should be able to get a project-scoped package' {
        Get-AzDOPackage -Feed ToolsTestFeed -Project Tools -PackageName 'Newtonsoft.json' |
            Select-Object -ExpandProperty name |
            Should -Be 'Newtonsoft.json'
    }

    It 'should be able to get a specific version of a project-scoped package' {
        Get-AzDOPackage -Feed ToolsTestFeed -Project Tools -PackageName 'Newtonsoft.json' -Version 12.0.2 |
            Select-Object -ExpandProperty versions |
            Select-Object -ExpandProperty version |
            Should -Be '12.0.2'
    }

    It 'should be able to get a package from pipeline input' {
        Get-AzDOPackageFeed -Name MyFeed | Get-AzDOPackage | Select-Object Name | Should -Not -BeNullOrEmpty
    }

    It 'should be able to get a package with a specific version from pipeline input' {
        Get-AzDOPackageFeed -Name MyFeed |
            Get-AzDOPackage -PackageName PSSiOps -Version 2.1.30 |
            Select-Object -ExpandProperty versions |
            Select-Object -ExpandProperty version |
            Should -Be '2.1.30'
    }

    It 'should be able to get a project-scoped package from pipeline input' {
        Get-AzDOPackageFeed -Name ToolsTestFeed -Project Tools |
            Get-AzDOPackage -PackageName 'Newtonsoft.json' |
            Select-Object -ExpandProperty Name |
            Should -Be 'Newtonsoft.json'
    }

    It 'should be able to download multiple versions of a package' {
        Get-AzDOPackage `
            -PackageName SetBuildAgents `
            -Version 0.1.10, 0.1.8 `
            -Feed ToolsFeed `
            -Destination $TestDrive/PSAzDevOps
        ( Get-ChildItem -Path $TestDrive/PSAzDevOps ).Name |
            Should -Contain 'SetBuildAgents.0.1.10'
        ( Get-ChildItem -Path $TestDrive/PSAzDevOps ).Name |
            Should -Contain 'SetBuildAgents.0.1.8'
    }
}
