Describe 'Get-AzDOProjectProcessId' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDO.psm1" -Force
    }

    Context 'when ProcessId is provided' {
        It 'should return the provided ProcessId' {
            $processId = '6b724f1d-ef1f-4f0d-9d3a-2c4f5f3e6a1b'
            $result = Get-AzDOProjectProcessId -ProcessId $processId
            $result | Should -BeExactly $processId
        }

        It 'should return ProcessId even if Project is also provided' {
            $processId = '6b724f1d-ef1f-4f0d-9d3a-2c4f5f3e6a1b'
            $project = [PSCustomObject]@{ name = 'MyProject' }
            $result = Get-AzDOProjectProcessId -ProcessId $processId -Project $project
            $result | Should -BeExactly $processId
        }
    }

    Context 'when ProcessId is not provided but Project is' {
        It 'should derive ProcessId from Project object' {
            $project = [PSCustomObject]@{
                name         = 'MyProject'
                capabilities = [PSCustomObject]@{
                    processTemplate = [PSCustomObject]@{
                        templateTypeId = 'scrum'
                    }
                }
            }
            $result = Get-AzDOProjectProcessId -Project $project `
                -CollectionUri 'https://dev.azure.com/myorg' `
                -Pat 'testtoken'
            $result | Should -BeExactly 'scrum'
        }
    }

    Context 'when neither ProcessId nor Project is provided' {
        It 'should throw an error' {
            { Get-AzDOProjectProcessId -CollectionUri 'https://dev.azure.com/myorg' -Pat 'testtoken' } |
                Should -Throw "ProcessId is required*"
        }
    }

    Context 'when piping a Project object' {
        It 'should accept Project via pipeline' {
            $project = [PSCustomObject]@{
                name         = 'MyProject'
                capabilities = [PSCustomObject]@{
                    processTemplate = [PSCustomObject]@{
                        templateTypeId = 'agile'
                    }
                }
            }
            $result = $project | Get-AzDOProjectProcessId -CollectionUri 'https://dev.azure.com/myorg' -Pat 'testtoken'
            $result | Should -BeExactly 'agile'
        }
    }
}
