Describe 'Tests' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDO.psm1" -Force
    }

    It 'should get build pipelines by ID' {
        Get-AzDOPipeline 6048, 8100 -Project MyProject, MyProject | Should -HaveCount 2
    }

    It 'should get build pipelines by name' {
        Get-AzDOPipeline PipelineTest-Short -Project MyProject, MyProject | Should -HaveCount 2
    }

    It 'should get a list of project build pipelines if name or id is not specified' {
        $pipelines = Get-AzDOPipeline -Project MyProject, MyProject
        $pipelines.id | Should -Contain '6048'
        $pipelines.id | Should -Contain '8100'
        $pipelines.Count | Should -BeGreaterThan 2
    }
}
