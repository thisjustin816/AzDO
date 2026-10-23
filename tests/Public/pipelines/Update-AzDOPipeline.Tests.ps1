Describe 'Integration Tests' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        . "$PSScriptRoot/../../Import-TestModule.ps1"
    }

    It 'should update a pipeline successfully' {
        $name = 'PipelineTest'
        $testPipeline = Get-AzDOPipeline -Name $name -Project Tools
        $testPipeline | Export-AzDOPipeline -Destination $TestDrive
        { $testPipeline | Update-AzDOPipeline -JsonFilePath "$TestDrive/$name.json" } | Should -Not -Throw
    }
}