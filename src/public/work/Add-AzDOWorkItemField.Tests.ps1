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

    Context 'when adding a field' {
        It 'should call Invoke-AzDORestApiMethod with POST to the process fields endpoint' {
            Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd { }

            Add-AzDOWorkItemField -ProcessId 'p1' -FieldName 'Custom.F1' -DisplayName 'F1' -FieldType 'string'

            Should -Invoke Invoke-AzDORestApiMethod -ModuleName AzDOCmd -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and `
                $Endpoint -eq 'work/processes/p1/fields'
            }
        }

        It 'should return the existing field when the API reports it already exists' {
            Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd -ParameterFilter { $Method -eq 'Post' } -MockWith { throw [System.Exception]::new('TF402571: already exists') }

            Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd -ParameterFilter { $Method -eq 'Get' } -MockWith {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ referenceName = 'Custom.F1'; name = 'F1' }) }
            }

            $result = Add-AzDOWorkItemField -ProcessId 'p1' -FieldName 'Custom.F1' -DisplayName 'F1' -FieldType 'string'

            $result | Should -Not -BeNullOrEmpty
            $result.referenceName | Should -Be 'Custom.F1'
        }

        It 'should derive ProcessId from Project when not provided' {
            Mock Invoke-AzDORestApiMethod -ModuleName AzDOCmd { }

            Add-AzDOWorkItemField -Project @{ name = 'MyProject' } -FieldName 'Custom.F2' -DisplayName 'F2' -FieldType 'string'

            Should -Invoke Invoke-AzDORestApiMethod -ModuleName AzDOCmd -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and `
                $Endpoint -eq 'work/processes/derivedProcess/fields'
            }
        }
    }
}
