Describe 'Integration Tests' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        . "$PSScriptRoot/../../Import-TestModule.ps1"
    }

    It 'should export a pipeline as json' {
        $name = 'PipelineTest'
        Get-AzDOPipeline -Name $name -Project Tools | Export-AzDOPipeline -Destination $TestDrive
        Get-Content -Path "$TestDrive/$name.json" | ConvertFrom-Json | Should -Not -BeNullOrEmpty
    }
}