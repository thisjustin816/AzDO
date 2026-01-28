Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        Mock Initialize-AzDORestApi -ModuleName AzDOCmd { @{ Headers = @{ Authorization = 'Bearer test' } } }

        Mock Get-AzDOProjectProcessId -ModuleName AzDOCmd {
            param($ProcessId)
            if ($ProcessId) {
                return $ProcessId
            }

            return 'derivedProcess'
        }
    }

    Context 'when adding a field to a work item type' {
        It 'should call Invoke-AzDORestApiMethod with POST to the workItemTypes fields endpoint' {
            Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd { }

            Add-AzDOWorkItemFieldToType -ProcessId 'p1' -WorkItemTypeRefName 'Microsoft.VSTS.WorkItemTypes.Task' -FieldRefName 'Custom.F1'

            Should -Invoke Invoke-AzDORestApiMethod -ModuleName AzDOCmd -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and `
                $Endpoint -eq 'work/processes/p1/workItemTypes/Microsoft.VSTS.WorkItemTypes.Task/fields'
            }
        }

        It 'should not throw if the field already exists in the work item type' {
            Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd -ParameterFilter { $Method -eq 'Post' } -MockWith { throw [System.Exception]::new('Field already contains') }

            { Add-AzDOWorkItemFieldToType -ProcessId 'p1' -WorkItemTypeRefName 'Microsoft.VSTS.WorkItemTypes.Task' -FieldRefName 'Custom.F1' } | Should -Not -Throw
        }

        It 'should derive ProcessId from Project when not provided' {
            Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd { }

            Add-AzDOWorkItemFieldToType -Project @{ name = 'MyProject' } -WorkItemTypeRefName 'Microsoft.VSTS.WorkItemTypes.Task' -FieldRefName 'Custom.F2'

            Should -Invoke Invoke-AzDORestApiMethod -ModuleName AzDOCmd -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and `
                $Endpoint -eq 'work/processes/derivedProcess/workItemTypes/Microsoft.VSTS.WorkItemTypes.Task/fields'
            }
        }
    }
}
