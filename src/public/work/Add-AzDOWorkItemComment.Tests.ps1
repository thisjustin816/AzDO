Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        $script:comment = "Pester test comment $( Get-Date )"
        $script:projectUrl = "https://dev.azure.com/MyOrg/$(( New-Guid ).Guid)/"

        Mock Get-AzDOWorkItem {
            [PSCustomObject]@{
                id = $Id
                fields = [PSCustomObject]@{
                    'System.TeamProject' = $Project
                }
                project = $Project
            }
        }

        Mock Set-AzDOWorkItemField -ModuleName AzDOCmd {
            [PSCustomObject]@{
                id = $Id
                fields = [PSCustomObject]@{
                    'System.WorkItemType' = 'User Story'
                    'System.Title' = 'Work Item Title'
                    'System.History' = @($script:comment)
                }
                url = "$($script:projectUrl)_apis/wit/workItems/12345"
            }
        }
    }

    It 'should output a custom object with a working url' {
        $workItem = Get-AzDOWorkItem 12345 -Project MyProject |
            Add-AzDOWorkItemComment -Comment $script:comment
        $workItem.Id | Should -Be 12345
        $workItem.Type | Should -Be 'User Story'
        $workItem.Title | Should -Be 'Work Item Title'
        $workItem.Comment | Should -Be $script:comment
        $workItem.Url | Should -Be "$($script:projectUrl)_workItems/edit/12345"
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        $script:comment = "Pester test comment $( Get-Date )"
    }

    It 'should add a comment to a work item' {
        Get-AzDOWorkItem 32161 -Project Tools |
            Add-AzDOWorkItemComment -Comment $script:comment |
            Select-Object -ExpandProperty Comment |
            Should -Be $script:comment
    }
}
