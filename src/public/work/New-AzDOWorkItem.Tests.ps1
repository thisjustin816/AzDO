Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should create new work items' {
        $script:feature = New-AzDOWorkItem `
            -Title 'Pester test feature' `
            -Type 'Feature' `
            -NoRetry `
            -Project 'MyProject'

        $script:feature | Should -Not -BeNullOrEmpty

        $script:task = New-AzDOWorkItem `
            -Title 'Pester test task' `
            -Type 'Task' `
            -NoRetry `
            -Project 'MyProject'

        $script:task | Should -Not -BeNullOrEmpty
    }

    Context 'When there are existing work items' {
        BeforeAll {
            if (!$script:feature -or !$script:task) {
                $script:feature = New-AzDOWorkItem `
                    -Title 'Pester test feature' `
                    -Type 'Feature' `
                    -NoRetry `
                    -Project 'MyProject'

                $script:task = New-AzDOWorkItem `
                    -Title 'Pester test task' `
                    -Type 'Task' `
                    -NoRetry `
                    -Project 'MyProject'
            }
        }

        It 'should create a work item with parent/child relationships' {
            $script:bug = New-AzDOWorkItem `
                    -Title 'Pester test bug' `
                    -Type 'Bug' `
                    -IterationPath 'Iteration 1' `
                    -ParentId $script:feature.id `
                    -ChildId $script:task.id `
                    -NoRetry `
                    -Project 'MyProject'

            $script:bug | Should -Not -BeNullOrEmpty
        }
    }

    AfterAll {
        Write-Host -Object "$($script:feature.id), $($script:bug.id), and $($script:task.id) should be deleted."
    }
}