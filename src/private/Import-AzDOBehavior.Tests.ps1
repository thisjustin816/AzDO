Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..' 'AzDOCmd.psm1') -Force

        . (Join-Path $PSScriptRoot 'Clear-AzDOObjectOrgData.ps1')
        . (Join-Path $PSScriptRoot 'Import-AzDOBehavior.ps1')

        Mock Clear-AzDOObjectOrgData {
            param($InputObject, $PropertiesToRemove)
            $cleanObj = $InputObject.PSObject.Copy()
            foreach ($prop in $PropertiesToRemove) {
                if ($cleanObj.PSObject.Properties[$prop]) {
                    $cleanObj.PSObject.Properties.Remove($prop)
                }
            }
            return $cleanObj
        }

        Mock Invoke-AzDORestApiMethod {
            param($Uri, $Method, $Body, $Headers, $NoRetry)
            return @{
                id = 'new-behavior-id'
                name = 'Created Behavior'
                referenceName = 'Custom.CreatedBehavior'
            }
        }
    }

    Context 'when importing behaviors' {
        It 'should skip organization-specific GUID behaviors' {
            $guidBehavior = [PSCustomObject]@{
                referenceName = 'Custom.12345678-1234-1234-1234-123456789abc'
                name = 'Test GUID Behavior'
                id = 'some-id'
                url = 'https://dev.azure.com'
            }

            $result = Import-AzDOBehavior -Behavior $guidBehavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id', 'url')

            $result.Skipped | Should -BeTrue
            $result.Reason | Should -Be 'Organization-specific GUID'
            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -Exactly 0 -Scope It
        }

        It 'should import valid custom behaviors' {
            $validBehavior = [PSCustomObject]@{
                referenceName = 'Custom.ValidBehavior'
                name = 'Valid Behavior'
                id = 'some-id'
                url = 'https://dev.azure.com'
            }

            $result = Import-AzDOBehavior -Behavior $validBehavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id', 'url')

            $result.Success | Should -BeTrue
            $result.Skipped | Should -BeFalse
            Should -Invoke -CommandName 'Clear-AzDOObjectOrgData' -Exactly 1 -Scope It
            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -Exactly 1 -Scope It
        }

        It 'should use POST method for creation' {
            $behavior = [PSCustomObject]@{
                referenceName = 'Custom.TestBehavior'
                name = 'Test Behavior'
                id = 'some-id'
            }

            Import-AzDOBehavior -Behavior $behavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id')

            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $Method -eq 'POST'
            } -Exactly 1 -Scope It
        }

        It 'should attempt PUT when POST fails and Force is specified' {
            Mock Invoke-AzDORestApiMethod {
                param($Uri, $Method, $Body, $Headers, $NoRetry)
                if ($Method -eq 'POST') {
                    throw "Behavior already exists"
                } else {
                    return @{
                        id = 'updated-behavior-id'
                        name = 'Updated Behavior'
                    }
                }
            }

            $behavior = [PSCustomObject]@{
                referenceName = 'Custom.ExistingBehavior'
                name = 'Existing Behavior'
                id = 'some-id'
            }

            $result = Import-AzDOBehavior -Behavior $behavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id') -Force

            $result.Success | Should -BeTrue
            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter { $Method -eq 'POST' } -Exactly 1 -Scope It
            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter { $Method -eq 'PUT' } -Exactly 1 -Scope It
        }

        It 'should fail when POST fails and Force is not specified' {
            # Mock POST to fail
            Mock Invoke-AzDORestApiMethod {
                throw "Behavior already exists"
            }

            $behavior = [PSCustomObject]@{
                referenceName = 'Custom.ExistingBehavior'
                name = 'Existing Behavior'
                id = 'some-id'
            }

            $result = Import-AzDOBehavior -Behavior $behavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id')

            $result.Success | Should -BeFalse
            $result.Error | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter { $Method -eq 'POST' } -Exactly 1 -Scope It
        }

        It 'should pass NoRetry parameter to API call' {
            $behavior = [PSCustomObject]@{
                referenceName = 'Custom.TestBehavior'
                name = 'Test Behavior'
                id = 'some-id'
            }

            Import-AzDOBehavior -Behavior $behavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id') -NoRetry

            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $NoRetry -eq $true
            } -Exactly 1 -Scope It
        }

        It 'should sanitize behavior object before import' {
            $behavior = [PSCustomObject]@{
                referenceName = 'Custom.TestBehavior'
                name = 'Test Behavior'
                id = 'some-id'
                url = 'https://dev.azure.com'
            }

            Import-AzDOBehavior -Behavior $behavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id', 'url')

            Should -Invoke -CommandName 'Clear-AzDOObjectOrgData' -ParameterFilter {
                $InputObject.referenceName -eq 'Custom.TestBehavior' -and
                $PropertiesToRemove -contains 'id' -and
                $PropertiesToRemove -contains 'url'
            } -Exactly 1 -Scope It
        }

        It 'should return structured result with all required properties' {
            $behavior = [PSCustomObject]@{
                referenceName = 'Custom.TestBehavior'
                name = 'Test Behavior'
                id = 'some-id'
            }

            $result = Import-AzDOBehavior -Behavior $behavior -ProcessId 'test-process-id' -ApiHeaders @{} -PropertiesToRemove @('id')

            $result.Success | Should -BeOfType [bool]
            $result.Skipped | Should -BeOfType [bool]
            $result.Success | Should -BeTrue
            $result.Skipped | Should -BeFalse
        }
    }
}
