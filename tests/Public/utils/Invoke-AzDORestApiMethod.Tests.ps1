Describe 'REST request handling' -Tag 'Unit' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/Public/utils/Initialize-AzDORestApi.ps1"
        . "$PSScriptRoot/../../../src/Public/utils/Invoke-AzDORestApiMethod.ps1"
    }

    BeforeEach {
        $script:attempt = 0
        $script:request = @{
            Method       = 'Get'
            Organization = 'fixture'
            Endpoint     = 'distributedtask/pools'
            Headers      = @{ Authorization = 'fixture-token' }
            ErrorAction  = 'Stop'
        }
        Mock Start-Sleep {}
    }

    It 'returns a successful response after transient failures' {
        Mock Invoke-RestMethod {
            $script:attempt++
            if ($script:attempt -lt 3) { throw [InvalidOperationException]::new('Transient connection failure') }
            [PSCustomObject]@{ count = 1; value = @([PSCustomObject]@{ name = 'Fixture'; id = 6018 }) }
        }
        $result = Invoke-AzDORestApiMethod @script:request
        $result.id | Should -Be 6018
        Should -Invoke Invoke-RestMethod -Times 3 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
    }

    It 'surfaces a non-HTTP failure after the retry limit' {
        Mock Invoke-RestMethod { throw [InvalidOperationException]::new('Connection unavailable') }
        { Invoke-AzDORestApiMethod @script:request } | Should -Throw '*Connection unavailable*'
        Should -Invoke Invoke-RestMethod -Times 7 -Exactly
        Should -Invoke Start-Sleep -Times 6 -Exactly
    }

    It 'surfaces a non-HTTP failure immediately with NoRetry' {
        Mock Invoke-RestMethod { throw [InvalidOperationException]::new('Connection unavailable') }
        { Invoke-AzDORestApiMethod @script:request -NoRetry } | Should -Throw '*Connection unavailable*'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 0
    }

    It 'makes no request under WhatIf' {
        Mock Invoke-RestMethod { throw 'Unexpected request' }
        Invoke-AzDORestApiMethod @script:request -WhatIf | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -Times 0
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/../../../src/Public/utils/Initialize-AzDORestApi.ps1
        . $PSScriptRoot/../../../src/Public/utils/Invoke-AzDORestApiMethod.ps1
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
