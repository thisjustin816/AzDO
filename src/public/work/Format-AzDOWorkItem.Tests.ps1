Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        $script:workItem = [PSCustomObject]@{
            id     = 12345
            fields = [PSCustomObject]@{
                'System.WorkItemType'  = 'User Story'
                'System.Title'         = 'Work Item Title'
                'System.State'         = 'Active'
                'System.AreaPath'      = 'MyProject\Area'
                'System.IterationPath' = 'MyProject\Iteration'
                'System.AssignedTo'    = 'John Doe'
            }
            _links = [PSCustomObject]@{
                html = [PSCustomObject]@{
                    href = 'https://dev.azure.com/MyOrg/MyProject/_workItems/edit/12345'
                }
            }
        }
    }

    It 'should output a custom object with basic properties' {
        $formattedWorkItem = $script:workItem | Format-AzDOWorkItem
        $formattedWorkItem.Id | Should -Be 12345
        $formattedWorkItem.Type | Should -Be 'User Story'
        $formattedWorkItem.Title | Should -Be 'Work Item Title'
        $formattedWorkItem.Url | Should -Be 'https://dev.azure.com/MyOrg/MyProject/_workItems/edit/12345'
    }

    It 'should output a custom object with expanded properties' {
        $formattedWorkItem = $script:workItem | Format-AzDOWorkItem -Expand
        $formattedWorkItem.Id | Should -Be 12345
        $formattedWorkItem.Type | Should -Be 'User Story'
        $formattedWorkItem.Title | Should -Be 'Work Item Title'
        $formattedWorkItem.State | Should -Be 'Active'
        $formattedWorkItem.AreaPath | Should -Be 'MyProject\Area'
        $formattedWorkItem.IterationPath | Should -Be 'MyProject\Iteration'
        $formattedWorkItem.AssignedTo | Should -Be 'John Doe'
        $formattedWorkItem.Url | Should -Be 'https://dev.azure.com/MyOrg/MyProject/_workItems/edit/12345'
    }
}
