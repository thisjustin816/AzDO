Describe 'Windows PowerShell REST transport' -Tag 'WindowsPowerShell' {
    BeforeAll {
        . "$PSScriptRoot/../src/Public/utils/Invoke-AzDORestApiMethod.ps1"
    }

    It 'returns every JSON page using the available Windows PowerShell transport' {
        $PSVersionTable.PSVersion.Major | Should -Be 5
        Mock Start-Sleep {}
        Mock Invoke-RestMethod { throw 'ResponseHeadersVariable is unavailable on Windows PowerShell' }
        Mock Invoke-WebRequest {
            if ($Uri -match 'continuationToken=') {
                [PSCustomObject]@{ Content = '{"count":1,"value":[{"id":2}]}'; Headers = @{} }
            }
            else {
                [PSCustomObject]@{
                    Content = '{"count":1,"value":[{"id":1}]}'
                    Headers = @{ 'X-MS-ContinuationToken' = 'next' }
                }
            }
        }
        $result = Invoke-AzDORestApiMethod -Method Get -Organization fixture -Endpoint build/builds `
            -Headers @{} -NoRetry -ErrorAction Stop
        $result.id | Should -Be @(1, 2)
        Should -Invoke Invoke-WebRequest -Times 2 -Exactly -ParameterFilter { $UseBasicParsing }
        Should -Invoke Invoke-RestMethod -Times 0
    }
}

Describe 'Work item JSON patches' -Tag 'Unit' {
    BeforeAll {
        Get-ChildItem -Path "$PSScriptRoot/../src/Private/*.ps1" | ForEach-Object { . $_.FullName }
        Get-ChildItem -Path "$PSScriptRoot/../src/Public" -Filter '*.ps1' -Recurse |
            ForEach-Object { . $_.FullName }
    }

    BeforeEach {
        Mock Initialize-AzDORestApi { @{} }
        Mock Invoke-AzDORestApiMethod { $Body }
        $script:arguments = @{
            Project       = 'Fixture'
            CollectionUri = 'https://dev.azure.com/fixture'
            Pat           = 'fixture'
            Confirm       = $false
            ErrorAction   = 'Stop'
        }
    }

    It 'serializes a single added relation as a JSON array' {
        Mock Get-AzDOWorkItem { [PSCustomObject]@{ url = 'https://example.invalid/workitems/2' } }
        $json = Add-AzDOWorkItemRelation @script:arguments -Id 1 -RelatedWorkItemId 2 -RelationType Child
        $json | Should -Match '^\['
        $patch = $json | ConvertFrom-Json
        $patch[0].value.url | Should -Be 'https://example.invalid/workitems/2'
    }

    It 'requires a relation type and rejects omission before initializing a request' {
        $parameter = (Get-Command Remove-AzDOWorkItemRelation).Parameters['RelationType']
        $attributes = $parameter.Attributes | Where-Object { $_ -is [Management.Automation.ParameterAttribute] }
        $attributes.Mandatory | Should -Contain $true
        $child = Join-Path $TestDrive 'Missing-RelationType.ps1'
        $marker = Join-Path $TestDrive 'api-reached.txt'
        @'
param ([String]$Source, [String]$Marker)
$ErrorActionPreference = 'Stop'
. $Source
function Initialize-AzDORestApi {
    Set-Content -LiteralPath $Marker -Value 'reached'
    throw 'The API boundary must not be reached.'
}
try {
    Remove-AzDOWorkItemRelation -Id 1 -Confirm:$false -ErrorAction Stop
    exit 0
}
catch {
    Write-Output $_.Exception.Message
    exit 1
}
'@ | Set-Content -LiteralPath $child
        $source = "$PSScriptRoot/../src/Public/work/Remove-AzDOWorkItemRelation.ps1"
        $output = & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File $child $source $marker
        $LASTEXITCODE | Should -Not -Be 0 -Because ($output -join [Environment]::NewLine)
        Test-Path -LiteralPath $marker | Should -BeFalse
    }

    It 'removes matching relations from the highest index first' {
        Mock Get-AzDOWorkItem {
            [PSCustomObject]@{
                relations = @(
                    [PSCustomObject]@{ rel = 'System.LinkTypes.Hierarchy-Forward' }
                    [PSCustomObject]@{ rel = 'System.LinkTypes.Related' }
                    [PSCustomObject]@{ rel = 'System.LinkTypes.Hierarchy-Forward' }
                )
            }
        }
        $json = Remove-AzDOWorkItemRelation @script:arguments -Id 1 -RelationType Child
        ($json | ConvertFrom-Json).path | Should -Be @('/relations/2', '/relations/0')
    }

    It 'does not send an empty patch when no relation matches' {
        Mock Get-AzDOWorkItem { [PSCustomObject]@{ relations = @() } }
        Remove-AzDOWorkItemRelation @script:arguments -Id 1 -RelationType Child -WarningAction SilentlyContinue
        Should -Invoke Invoke-AzDORestApiMethod -Times 0
    }

    It 'serializes work item fields as a JSON array' {
        Mock Get-AzDOWorkItemType { 'User Story' }
        Mock Invoke-AzDORestApiMethod {
            $Body | Should -Match '^\['
            $patch = $Body | ConvertFrom-Json
            $patch[0].value | Should -Be 'Fixture title'
            [PSCustomObject]@{ id = 123; fields = @{ 'System.TeamProject' = 'Fixture' } }
        }
        (New-AzDOWorkItem @script:arguments -Title 'Fixture title').id | Should -Be 123
    }
}
