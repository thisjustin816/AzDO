Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/Initialize-AzDORestApi.ps1
        . $PSScriptRoot/Invoke-AzDORestApiMethod.ps1
        $script:RestError = try {
            Invoke-RestMethod `
                -Uri 'https://dev.azure.com/MyOrg/_apis/distributedtask/pools?api-version=5.1' `
                -Headers ( Initialize-AzDORestApi )
        }
        catch {
            $_
        }
    }

    BeforeEach {
        $script:MockCounter = 0
    }

    Context 'a couple retries' {
        BeforeAll {
            Mock Invoke-RestMethod {
                $script:MockCounter++
                if ($script:MockCounter -lt 3) {
                    throw $script:RestError
                }
                else {
                    [PSCustomObject]@{
                        count = 1
                        value = [PSCustomObject]@{
                            name = 'AzDO'
                            id   = 6018
                        }
                    }
                }
            }
        }

        It 'should retry calls and not throw if errors are encountered' {
            $restArgs = @{
                Method       = 'Get'
                Organization = 'MyOrg'
                Endpoint     = 'distributedtask/pools'
                Headers      = Initialize-AzDORestApi
                ApiVersion   = '5.1'
            }
            { Invoke-AzDORestApiMethod @restArgs } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly
            Invoke-AzDORestApiMethod @restArgs | Should -Not -BeNullOrEmpty
        }
    }

    Context 'use all retries' {
        BeforeAll {
            Mock Invoke-RestMethod {
                throw $script:RestError
            }

            Mock Start-Sleep
        }

        It 'should throw if all retries are used' {
            $restArgs = @{
                Method       = 'Get'
                Organization = 'MyOrg'
                Endpoint     = 'distributedtask/pools'
                Headers      = Initialize-AzDORestApi
                ApiVersion   = '5.1'
            }
            { Invoke-AzDORestApiMethod @restArgs -ErrorAction Stop } | Should -Throw
            Should -Invoke Invoke-RestMethod -Times 7 -Exactly
        }
    }

    Context 'use all retries' {
        BeforeAll {
            Mock Invoke-RestMethod {
                throw $script:RestError
            }
        }

        It 'should throw immediately if -NoRetry is used' {
            $restArgs = @{
                Method       = 'Get'
                Organization = 'MyOrg'
                Endpoint     = 'distributedtask/pools'
                Headers      = Initialize-AzDORestApi
                ApiVersion   = '5.1'
            }
            { Invoke-AzDORestApiMethod @restArgs -NoRetry -ErrorAction Stop } | Should -Throw
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Initialize-AzDORestApi.ps1
        . $PSScriptRoot/Invoke-AzDORestApiMethod.ps1
    }
    It 'should successfully call an api without a project parameter' {
        $restArgs = @{
            Method       = 'Get'
            Organization = 'MyOrg'
            Endpoint     = 'distributedtask/pools'
            Headers      = Initialize-AzDORestApi
            ApiVersion   = '5.1'
        }
        Invoke-AzDORestApiMethod @restArgs | Should -Not -BeNullOrEmpty
    }

    It 'should successfully call an api with a project parameter' {
        $restArgs = @{
            Method       = 'Get'
            Organization = 'MyOrg'
            Project      = 'MyProject'
            Endpoint     = 'build/definitions'
            Params       = 'name=AzDO'
            Headers      = Initialize-AzDORestApi
            ApiVersion   = '5.1'
        }
        Invoke-AzDORestApiMethod @restArgs | Should -Not -BeNullOrEmpty
    }

    It 'should add the subdomain to the default base URL: <CollectionUri>' -TestCases @(
        @{ CollectionUri = 'https://dev.azure.com/myorg/' }
        @{ CollectionUri = 'https://myorg.visualstudio.com/' }
    ) {
        param ($CollectionUri)
        (
            Invoke-AzDORestApiMethod `
                -Method 'Get' `
                -CollectionUri $CollectionUri `
                -SubDomain 'feeds' `
                -Endpoint 'packaging/feeds' `
                -Params 'name=ScmFeed' `
                -ApiVersion '5.1-preview.1' `
                -Headers ( Initialize-AzDORestApi ) `
                -Verbose `
                4>&1
        ) -join ', ' |
            Should -Match ([Regex]::Escape('https://feeds.dev.azure.com'))
    }
}
