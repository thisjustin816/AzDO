[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars', '',
    Justification = 'The REST mock crosses scopes; each test restores the original response-header value.'
)]
param ()

Describe 'REST response handling' -Tag 'Unit' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/Public/utils/Invoke-AzDORestApiMethod.ps1"
    }

    BeforeEach {
        $script:originalHeaders = Get-Variable -Name responseHeaders -Scope Global -ErrorAction SilentlyContinue
        $script:originalHeadersValue = if ($script:originalHeaders) { $script:originalHeaders.Value }
        $script:pageAttempts = 0
        $script:request = @{
            Method       = 'Get'
            Organization = 'fixture'
            Endpoint     = 'build/builds'
            Headers      = @{}
            ErrorAction  = 'Stop'
        }
        Mock Start-Sleep {}
    }

    AfterEach {
        if ($script:originalHeaders) {
            Set-Variable -Name responseHeaders -Scope Global -Value $script:originalHeadersValue
        }
        else {
            Remove-Variable -Name responseHeaders -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'restarts paging from the first page after a later request fails' {
        Mock Invoke-RestMethod {
            if ($Uri -match 'continuationToken=') {
                $script:pageAttempts++
                if ($script:pageAttempts -eq 1) {
                    throw [InvalidOperationException]::new('Page temporarily unavailable')
                }
                $global:responseHeaders = @{}
                [PSCustomObject]@{ count = 1; value = @([PSCustomObject]@{ id = 2 }) }
            }
            else {
                $global:responseHeaders = @{ 'X-MS-ContinuationToken' = 'next' }
                [PSCustomObject]@{ count = 1; value = @([PSCustomObject]@{ id = 1 }) }
            }
        }

        $result = @(Invoke-AzDORestApiMethod @script:request)
        $result.id | Should -Be @(1, 2)
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter {
            $Uri -notmatch 'continuationToken='
        }
    }

    It 'escapes continuation tokens as query values' {
        Mock Invoke-RestMethod {
            if ($Uri -match 'continuationToken=') {
                $global:responseHeaders = @{}
                [PSCustomObject]@{ count = 0; value = @() }
            }
            else {
                $global:responseHeaders = @{ 'X-MS-ContinuationToken' = 'a+b&c=d' }
                [PSCustomObject]@{ count = 1; value = @([PSCustomObject]@{ id = 1 }) }
            }
        }

        Invoke-AzDORestApiMethod @script:request | Should -Not -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*&continuationToken=a%2Bb%26c%3Dd'
        }
    }

    It 'reports an authorization page as an error' {
        Mock Invoke-RestMethod { '<html>Azure DevOps Services | Sign In</html>' }
        { Invoke-AzDORestApiMethod @script:request -NoRetry } | Should -Throw '*Not authorized*'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'does not report a stale download as successful after an error' {
        $download = Join-Path $TestDrive 'download.json'
        Set-Content -LiteralPath $download -Value 'Previous download'
        Mock Invoke-RestMethod { throw [InvalidOperationException]::new('Download failed') }
        $script:request.ErrorAction = 'SilentlyContinue'
        Invoke-AzDORestApiMethod @script:request -NoRetry -OutFile $download | Should -BeNullOrEmpty
    }
}
