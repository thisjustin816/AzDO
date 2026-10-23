Describe 'Set-AzPipelinesVariable' -Tag 'Unit', 'WindowsPowerShell' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/Private/ConvertTo-AzPipelinesLoggingValue.ps1"
        . "$PSScriptRoot/../../../src/Public/pipelines/Set-AzPipelinesVariable.ps1"
    }

    BeforeEach {
        $script:originalJobName = $env:AGENT_JOBNAME
        $env:AGENT_JOBNAME = 'fixture-job'
    }

    AfterEach {
        $env:AGENT_JOBNAME = $script:originalJobName
    }

    It 'emits the agent command without changing the process environment' {
        $name = 'AZDOCMD_VARIABLE_FIXTURE'
        $original = [Environment]::GetEnvironmentVariable($name, 'Process')
        $records = @(Set-AzPipelinesVariable -Name $name -Value 'fixture' 6>&1)
        $records | Should -HaveCount 1
        [String]$records[0] | Should -BeExactly "##vso[task.setvariable variable=$name]fixture"
        [Environment]::GetEnvironmentVariable($name, 'Process') | Should -BeExactly $original
    }

    It 'does nothing outside an agent job, including for PATH and PassThru' {
        $env:AGENT_JOBNAME = $null
        @(Set-AzPipelinesVariable -Name PATH -Value 'fixture' -PassThru *>&1) | Should -HaveCount 0
    }

    It 'guards PATH without writing a command or returning a value' {
        $warnings = @()
        @(Set-AzPipelinesVariable -Name pAtH -Value 'fixture' -PassThru -WarningVariable warnings 3>$null 6>&1) |
            Should -HaveCount 0
        $warnings | Should -HaveCount 1
    }

    It 'permits an explicit PATH override' {
        $records = @(Set-AzPipelinesVariable -Name PATH -Value 'fixture' -Force 6>&1)
        [String]$records[0] | Should -BeExactly '##vso[task.setvariable variable=PATH]fixture'
    }

    It 'returns the unescaped input only when PassThru is requested' {
        $value = "a;b]`n%0A"
        $result = Set-AzPipelinesVariable -Name example -Value $value -PassThru 6>$null
        $result.Name | Should -BeExactly 'example'
        $result.Value | Should -BeExactly $value
        @(Set-AzPipelinesVariable -Name example -Value fixture 6>$null) | Should -HaveCount 0
    }

    It 'emits an empty value for <Label>' -ForEach @(
        @{ Label = 'null'; Value = $null }
        @{ Label = 'an empty string'; Value = '' }
    ) {
        $records = @(Set-AzPipelinesVariable -Name example -Value $Value 6>&1)
        [String]$records[0] | Should -BeExactly '##vso[task.setvariable variable=example]'
    }

    It 'escapes <Label> in command data' -ForEach @(
        @{ Label = 'a literal encoded newline'; Value = '%0A'; Encoded = '%AZP250A' }
        @{ Label = 'a semicolon'; Value = 'a;b'; Encoded = 'a%3Bb' }
        @{ Label = 'a closing bracket'; Value = 'a]b'; Encoded = 'a%5Db' }
        @{ Label = 'a carriage return'; Value = "a`rb"; Encoded = 'a%0Db' }
        @{ Label = 'a newline'; Value = "a`nb"; Encoded = 'a%0Ab' }
    ) {
        $records = @(Set-AzPipelinesVariable -Name example -Value $Value 6>&1)
        $records | Should -HaveCount 1
        [String]$records[0] | Should -BeExactly "##vso[task.setvariable variable=example]$Encoded"
    }

    It 'keeps property delimiters inside the supplied variable name' {
        $records = @(Set-AzPipelinesVariable -Name 'x];isSecret=true' -Value fixture 6>&1)
        [String]$records[0] |
            Should -BeExactly '##vso[task.setvariable variable=x%5D%3BisSecret=true]fixture'
    }

    It 'processes each pipeline object separately' {
        $inputs = @(
            [PSCustomObject]@{ Name = 'one'; Value = 'a' }
            [PSCustomObject]@{ Name = 'two'; Value = 'b' }
        )
        $records = @($inputs | Set-AzPipelinesVariable 6>&1)
        $records | Should -HaveCount 2
        [String]$records[0] | Should -BeExactly '##vso[task.setvariable variable=one]a'
        [String]$records[1] | Should -BeExactly '##vso[task.setvariable variable=two]b'
    }

    It 'does not let Force bypass WhatIf' {
        Mock Write-Host {}
        @(Set-AzPipelinesVariable -Name PATH -Value fixture -Force -PassThru -WhatIf) | Should -HaveCount 0
        Should -Invoke Write-Host -Times 0 -Exactly
    }

    It 'rejects an empty variable name' {
        { Set-AzPipelinesVariable -Name '' -Value fixture } | Should -Throw
    }
}
