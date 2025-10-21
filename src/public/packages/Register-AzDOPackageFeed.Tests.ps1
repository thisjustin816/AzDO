BeforeAll {
    Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
}

InModuleScope 'AzDOCmd' {
    Describe 'Register-AzDOPackageFeed' {
        BeforeAll {        
            # Mock all external dependencies
            Mock Set-EnvironmentVariable { }
            Mock Register-PackageSource { 
                return [PSCustomObject]@{
                    Name      = $Name
                    Location  = $Location
                    IsTrusted = $true
                }
            }
            Mock Get-PackageSource { }
            Mock Unregister-PackageSource { }
        }

        BeforeEach {
            # Reset environment before each test
            $env:NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED = $null
            $env:ARTIFACTS_CREDENTIALPROVIDER_FEED_ENDPOINTS = $null
        }

        Context 'Parameter validation' {
            It 'requires a feed name' {
                { Register-AzDOPackageFeed -Name $null } | Should -Throw
                { Register-AzDOPackageFeed -Name '' } | Should -Throw
            }

            It 'validates FeedVersion is 2 or 3' {
                { Register-AzDOPackageFeed -Name 'test' -FeedVersion 1 } | Should -Throw
                { Register-AzDOPackageFeed -Name 'test' -FeedVersion 4 } | Should -Throw
            }
        }

        Context 'Environment setup' {
            It 'enables session token cache' {
                Register-AzDOPackageFeed -Name 'test'
            
                Should -Invoke Set-EnvironmentVariable -ParameterFilter { 
                    $Name -eq 'NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED' -and 
                    $Value -eq $true 
                }
                $env:NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED | Should -Be 'true'
            }

            It 'sets up credentials in environment' {
                $testPat = 'test-pat'
                $testName = 'test-feed'
            
                Register-AzDOPackageFeed -Name $testName -Pat $testPat
            
                $env:ARTIFACTS_CREDENTIALPROVIDER_FEED_ENDPOINTS | Should -Not -BeNullOrEmpty
                $credentials = $env:ARTIFACTS_CREDENTIALPROVIDER_FEED_ENDPOINTS | ConvertFrom-Json
                $credentials.endpointCredentials | Should -Not -BeNullOrEmpty
                $credentials.endpointCredentials[0].password | Should -Be $testPat
            }
        }

        Context 'Feed URL construction' {
            It 'constructs correct v3 URL for org-scoped feed' {
                $testName = 'test-feed'
                $orgName = 'test-org'
                $collectionUri = "https://dev.azure.com/$orgName"
                $expectedUrl = "https://pkgs.dev.azure.com/$orgName/_packaging/$testName/nuget/v3/index.json"
            
                Mock Get-PackageSource { }
            
                Register-AzDOPackageFeed -Name $testName `
                    -CollectionUri $collectionUri `
                    -FeedVersion 3
            
                Should -Invoke Register-PackageSource -ParameterFilter {
                    $Location -eq $expectedUrl
                }
            }

            It 'constructs correct v3 URL for project-scoped feed' {
                $testName = 'test-feed'
                $orgName = 'test-org'
                $projectName = 'test-project'
                $collectionUri = "https://dev.azure.com/$orgName"
                $expectedUrl = "https://pkgs.dev.azure.com/$orgName/$projectName/_packaging/$testName/nuget/v3/index.json"
            
                Mock Get-PackageSource { }
            
                Register-AzDOPackageFeed -Name $testName `
                    -CollectionUri $collectionUri `
                    -Project $projectName `
                    -FeedVersion 3
            
                Should -Invoke Register-PackageSource -ParameterFilter {
                    $Location -eq $expectedUrl
                }
            }

            It 'constructs correct v2 URL for org-scoped feed' {
                $testName = 'test-feed'
                $orgName = 'test-org'
                $collectionUri = "https://dev.azure.com/$orgName"
                $expectedUrl = "https://pkgs.dev.azure.com/$orgName/_packaging/$testName/nuget/v2"
            
                Mock Get-PackageSource { }
            
                Register-AzDOPackageFeed -Name $testName `
                    -CollectionUri $collectionUri `
                    -FeedVersion 2
            
                Should -Invoke Register-PackageSource -ParameterFilter {
                    $Location -eq $expectedUrl
                }
            }

            It 'constructs correct v2 URL for project-scoped feed' {
                $testName = 'test-feed'
                $orgName = 'test-org'
                $projectName = 'test-project'
                $collectionUri = "https://dev.azure.com/$orgName"
                $expectedUrl = "https://pkgs.dev.azure.com/$orgName/$projectName/_packaging/$testName/nuget/v2"
            
                Mock Get-PackageSource { }
            
                Register-AzDOPackageFeed -Name $testName `
                    -CollectionUri $collectionUri `
                    -Project $projectName `
                    -FeedVersion 2
            
                Should -Invoke Register-PackageSource -ParameterFilter {
                    $Location -eq $expectedUrl
                }
            }
        }

        Context 'Package source registration' {
            It 'registers package source with correct credentials' {
                $testName = 'test-feed'
                $testPat = 'test-pat'
            
                Register-AzDOPackageFeed -Name $testName -Pat $testPat
            
                Should -Invoke Register-PackageSource -ParameterFilter {
                    $Name -eq $testName -and
                    $ProviderName -eq 'NuGet' -and
                    $Credential.UserName -eq 'PAT' -and
                    $Credential.GetNetworkCredential().Password -eq $testPat
                }
            }

            It 'respects Force parameter' {
                $testName = 'test-feed'
            
                Register-AzDOPackageFeed -Name $testName -Force
            
                Should -Invoke Register-PackageSource -ParameterFilter {
                    $Force -eq $true
                }
            }
        }
    }
}
