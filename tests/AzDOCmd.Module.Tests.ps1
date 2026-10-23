Describe 'Built module contract' -Tag 'Unit' {
    BeforeAll {
        $script:sourceManifest = Import-PowerShellDataFile "$PSScriptRoot/../src/AzDOCmd.psd1"
        $version = $script:sourceManifest.ModuleVersion
        $script:builtRoot = "$PSScriptRoot/../out/AzDOCmd/$version"
        $script:builtManifest = Import-PowerShellDataFile "$script:builtRoot/AzDOCmd.psd1"
        . "$PSScriptRoot/Import-TestModule.ps1"
    }

    It 'retains the published module identity and runtime support' {
        $script:builtManifest.GUID | Should -Be 'a145d090-e911-4298-8744-dd3b04b4d4e5'
        $script:builtManifest.PowerShellVersion | Should -Be '5.1'
        $script:builtManifest.CompatiblePSEditions | Should -Be @('Desktop', 'Core')
    }

    It 'retains all published commands without exporting private or dependency commands' {
        $published = Get-Content "$PSScriptRoot/fixtures/AzDOCmd-2.4.0-exports.json" -Raw | ConvertFrom-Json
        $expected = @($published) + 'Set-AzPipelinesVariable' | Sort-Object
        $actual = (Get-Command -Module AzDOCmd).Name | Sort-Object
        Compare-Object -ReferenceObject $expected -DifferenceObject $actual | Should -BeNullOrEmpty
        $actual | Should -HaveCount 55
    }

    It 'does not package tests or depend on the source checkout' {
        Get-ChildItem $script:builtRoot -Recurse -Filter '*.Tests.ps1' | Should -BeNullOrEmpty
        Get-Content "$script:builtRoot/AzDOCmd.psm1" -Raw |
            Should -Not -Match '\$PSScriptRoot/(\.\./|Get-AzDOApiProjectName)'
    }

    It 'loads private relation and project helpers inside the built module' {
        InModuleScope AzDOCmd {
            (Get-AzDOWorkItemRelationTypeMap).Parent | Should -Be 'System.LinkTypes.Hierarchy-Reverse'
            (Get-AzDOWorkItemRelationTypeMap).Count | Should -Be 5
            [PSCustomObject]@{ name = 'Project A' } | Get-AzDOApiProjectName | Should -Be 'Project A'
            Export-EncodedUri -Uri 'Shared Queries/Work' | Should -Be 'Shared%20Queries%2FWork'
        }
    }
}
