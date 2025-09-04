Describe 'Export-AzDOWorkItemProcess' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        # Mock REST API calls
        Mock -CommandName Invoke-AzDORestApiMethod -MockWith {
            $endpoint = $args[0].Endpoint
            switch -Regex ($endpoint) {
                'work/processes$' {
                    @(
                        @{
                            name = 'Agile'
                            typeId = 'agile-id'
                            description = 'Agile process template'
                        }
                    )
                }
                '^work/processes/[\w-]+$' {
                    @{
                        name = 'Agile'
                        typeId = 'agile-id'
                        description = 'Agile process template'
                        referenceName = 'Agile'
                    }
                }
                'processes/[\w-]+/workitemtypes$' {
                    @(
                        @{
                            name = 'User Story'
                            referenceName = 'Microsoft.VSTS.WorkItemTypes.UserStory'
                            description = 'User story work item type'
                            color = '#009CCC'
                            icon = 'icon-story'
                            isDisabled = $false
                        }
                    )
                }
                'workitemtypes/.+/fields$' {
                    @(
                        @{
                            name = 'Story Points'
                            referenceName = 'Microsoft.VSTS.Scheduling.StoryPoints'
                            type = 'Double'
                            description = 'Effort estimate for the story'
                        }
                    )
                }
                'workitemtypes/.+/rules$' {
                    @(
                        @{
                            ruleName = 'Required Fields'
                            conditions = @()
                            actions = @(
                                @{
                                    actionType = 'READONLY'
                                    targetField = 'System.State'
                                }
                            )
                        }
                    )
                }
                'workitemtypes/.+/states$' {
                    @(
                        @{
                            name = 'New'
                            color = '#b2b2b2'
                            stateCategory = 'Proposed'
                        }
                    )
                }
                'workitemtypes/.+/behaviors$' {
                    @(
                        @{
                            behavior = @{
                                name = 'System.State'
                                reference = 'System.State'
                            }
                        }
                    )
                }
                'workitemtypes/.+/layout$' {
                    @{
                        pages = @(
                            @{
                                id = 'details'
                                label = 'Details'
                                groups = @(
                                    @{
                                        id = 'basics'
                                        label = 'Basic Info'
                                        controls = @()
                                    }
                                )
                            }
                        )
                    }
                }
                'processes/[\w-]+/behaviors$' {
                    @(
                        @{
                            name = 'System.CommonStates'
                            reference = 'System.CommonStates'
                            color = '#666666'
                        }
                    )
                }
                'processes/[\w-]+/fields$' {
                    @(
                        @{
                            name = 'Custom Field'
                            type = 'String'
                            description = 'Custom process field'
                        }
                    )
                }
                default { @{} }
            }
        } -ParameterFilter { $true }
    }

    Context 'when the process exists' {
        It 'should export the complete process definition with all components' {
            $processName = 'Agile'
            $result = Export-AzDOWorkItemProcess -ProcessName $processName -Destination $TestDrive

            # Verify basic file creation
            $result | Should -Not -BeNullOrEmpty
            $result.FullName | Should -Be "$TestDrive/$($processName.ToLower()).json"
            Test-Path -Path $result.FullName | Should -BeTrue

            # Parse exported content
            $content = Get-Content -Path $result.FullName -Raw | ConvertFrom-Json

            # Verify process metadata
            $content.name | Should -Be $processName
            $content.typeId | Should -Be 'agile-id'
            $content.description | Should -Be 'Agile process template'

            # Verify process fields were retrieved
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'processes/[\w-]+/fields$'
            }
            $content.fields | Should -Not -BeNullOrEmpty
            $content.fields[0].name | Should -Be 'Custom Field'

            # Verify process behaviors were retrieved
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'processes/[\w-]+/behaviors$'
            }
            $content.behaviors | Should -Not -BeNullOrEmpty
            $content.behaviors[0].name | Should -Be 'System.CommonStates'

            # Verify work item types were retrieved
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'processes/[\w-]+/workitemtypes$'
            }
            $content.workItemTypes | Should -Not -BeNullOrEmpty
            $content.workItemTypes[0].name | Should -Be 'User Story'

            # Verify work item type components were retrieved
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/fields$'
            }
            $content.workItemTypes[0].fields | Should -Not -BeNullOrEmpty
            $content.workItemTypes[0].fields[0].name | Should -Be 'Story Points'

            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/states$'
            }
            $content.workItemTypes[0].states | Should -Not -BeNullOrEmpty
            $content.workItemTypes[0].states[0].name | Should -Be 'New'

            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/rules$'
            }
            $content.workItemTypes[0].rules | Should -Not -BeNullOrEmpty
            $content.workItemTypes[0].rules[0].ruleName | Should -Be 'Required Fields'

            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/behaviors$'
            }
            $content.workItemTypes[0].behaviors | Should -Not -BeNullOrEmpty
            $content.workItemTypes[0].behaviors[0].behavior.name | Should -Be 'System.State'

            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/layout$'
            }
            $content.workItemTypes[0].layout | Should -Not -BeNullOrEmpty
            $content.workItemTypes[0].layout.pages[0].label | Should -Be 'Details'
        }
    }

    Context 'when the process does not exist' {
        BeforeAll {
            Mock -CommandName Invoke-AzDORestApiMethod -MockWith {
                @() # Return empty array for process list
            } -ParameterFilter {
                $endpoint -eq 'work/processes'
            }
        }

        It 'should write a warning' {
            $processName = 'NonExistentProcess'
            Export-AzDOWorkItemProcess -ProcessName $processName -Destination $TestDrive
            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -eq "Process '$processName' not found."
            }
        }
    }

    Context 'when API calls fail' {
        BeforeAll {
            Mock -CommandName Invoke-AzDORestApiMethod -MockWith {
                throw "API Error"
            } -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/fields$'
            }
        }

        It 'should continue exporting other components' {
            $processName = 'Agile'
            $result = Export-AzDOWorkItemProcess -ProcessName $processName -Destination $TestDrive

            # Should still create the file
            $result | Should -Not -BeNullOrEmpty
            Test-Path -Path $result.FullName | Should -BeTrue

            # Should still have other components
            $content = Get-Content -Path $result.FullName -Raw | ConvertFrom-Json
            $content.name | Should -Be $processName
            $content.workItemTypes | Should -Not -BeNullOrEmpty
            $content.workItemTypes[0].states | Should -Not -BeNullOrEmpty
        }
    }
}
