Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        . "$PSScriptRoot/../../Import-TestModule.ps1"

        Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd {
            [PSCustomObject]@{
                id     = 12345
                fields = [PSCustomObject]@{
                    'System.TeamProject' = $Project
                }
            }
        }
    }

    It 'should add the project field as an object property' {
        $workItem = Get-AzDOWorkItem 12345 -Project MyProject
        $workItem.project | Should -Be 'MyProject'
    }

    It 'should take a work item as pipeline input' {
        $workItem = Get-AzDOWorkItem 12345 -Project MyProject
        $workItem | Get-AzDOWorkItem | Should -Not -BeNullOrEmpty
    }
}