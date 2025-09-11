Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../AzDOCmd.psm1" -Force

        # Dot source the function under test
        . "$PSScriptRoot/Clear-AzDOObjectOrgData.ps1"
    }

    Context 'when clearing org-specific data from objects' {
        It 'should remove default org-specific properties' {
            $testObject = [PSCustomObject]@{
                id = '12345'
                name = 'TestProcess'
                url = 'https://dev.azure.com/myorg'
                _links = @{ self = @{ href = 'some-url' } }
                customization = 'some-value'
                inherits = 'base-process'
                rank = 1
                description = 'A test process'
            }

            $result = Clear-AzDOObjectOrgData -InputObject $testObject

            $result.name | Should -Be 'TestProcess'
            $result.description | Should -Be 'A test process'
            $result.PSObject.Properties['id'] | Should -BeNullOrEmpty
            $result.PSObject.Properties['url'] | Should -BeNullOrEmpty
            $result.PSObject.Properties['_links'] | Should -BeNullOrEmpty
            $result.PSObject.Properties['customization'] | Should -BeNullOrEmpty
            $result.PSObject.Properties['inherits'] | Should -BeNullOrEmpty
            $result.PSObject.Properties['rank'] | Should -BeNullOrEmpty
        }

        It 'should remove custom properties when specified' {
            $testObject = [PSCustomObject]@{
                name = 'TestProcess'
                secretProperty = 'remove-me'
                keepProperty = 'keep-me'
            }

            $result = Clear-AzDOObjectOrgData -InputObject $testObject -PropertiesToRemove @('secretProperty')

            $result.name | Should -Be 'TestProcess'
            $result.keepProperty | Should -Be 'keep-me'
            $result.PSObject.Properties['secretProperty'] | Should -BeNullOrEmpty
        }

        It 'should handle nested objects recursively' {
            $testObject = [PSCustomObject]@{
                name = 'Parent'
                nested = [PSCustomObject]@{
                    id = '123'
                    name = 'Child'
                    url = 'https://example.com'
                }
            }

            $result = Clear-AzDOObjectOrgData -InputObject $testObject

            $result.name | Should -Be 'Parent'
            $result.nested.name | Should -Be 'Child'
            $result.nested.PSObject.Properties['id'] | Should -BeNullOrEmpty
            $result.nested.PSObject.Properties['url'] | Should -BeNullOrEmpty
        }

        It 'should handle arrays of objects' {
            $testObject = [PSCustomObject]@{
                name = 'Parent'
                items = @(
                    [PSCustomObject]@{ id = '1'; name = 'Item1'; url = 'url1' },
                    [PSCustomObject]@{ id = '2'; name = 'Item2'; url = 'url2' }
                )
            }

            $result = Clear-AzDOObjectOrgData -InputObject $testObject

            $result.name | Should -Be 'Parent'
            $result.items.Count | Should -Be 2
            $result.items[0].name | Should -Be 'Item1'
            $result.items[1].name | Should -Be 'Item2'
            $result.items[0].PSObject.Properties['id'] | Should -BeNullOrEmpty
            $result.items[1].PSObject.Properties['id'] | Should -BeNullOrEmpty
            $result.items[0].PSObject.Properties['url'] | Should -BeNullOrEmpty
            $result.items[1].PSObject.Properties['url'] | Should -BeNullOrEmpty
        }

        It 'should handle empty input gracefully' {
            $emptyObject = [PSCustomObject]@{}
            $result = Clear-AzDOObjectOrgData -InputObject $emptyObject
            # Function returns null for empty objects since they are falsy
            $result | Should -BeNull
        }

        It 'should not modify the original object' {
            $originalObject = [PSCustomObject]@{
                id = '12345'
                name = 'TestProcess'
                url = 'https://dev.azure.com/myorg'
            }

            $result = Clear-AzDOObjectOrgData -InputObject $originalObject

            # Original should still have all properties
            $originalObject.PSObject.Properties['id'] | Should -Not -BeNullOrEmpty
            $originalObject.PSObject.Properties['url'] | Should -Not -BeNullOrEmpty
            $originalObject.id | Should -Be '12345'
            $originalObject.url | Should -Be 'https://dev.azure.com/myorg'

            # Result should have properties removed
            $result.PSObject.Properties['id'] | Should -BeNullOrEmpty
            $result.PSObject.Properties['url'] | Should -BeNullOrEmpty
            $result.name | Should -Be 'TestProcess'
        }

        It 'should handle deeply nested structures' {
            $testObject = [PSCustomObject]@{
                name = 'Root'
                level1 = [PSCustomObject]@{
                    id = 'level1-id'
                    name = 'Level1'
                    level2 = [PSCustomObject]@{
                        id = 'level2-id'
                        name = 'Level2'
                        url = 'level2-url'
                        items = @(
                            [PSCustomObject]@{ id = 'item1'; name = 'Item1' }
                        )
                    }
                }
            }

            $result = Clear-AzDOObjectOrgData -InputObject $testObject

            $result.name | Should -Be 'Root'
            $result.level1.name | Should -Be 'Level1'
            $result.level1.level2.name | Should -Be 'Level2'
            $result.level1.level2.items[0].name | Should -Be 'Item1'

            # All IDs and URLs should be removed
            $result.level1.PSObject.Properties['id'] | Should -BeNullOrEmpty
            $result.level1.level2.PSObject.Properties['id'] | Should -BeNullOrEmpty
            $result.level1.level2.PSObject.Properties['url'] | Should -BeNullOrEmpty
            $result.level1.level2.items[0].PSObject.Properties['id'] | Should -BeNullOrEmpty
        }
    }
}
