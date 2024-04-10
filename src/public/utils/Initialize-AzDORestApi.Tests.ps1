Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Initialize-AzDORestApi.ps1
    }
    It 'should return a valid <_> token' -TestCases ('Basic', 'Bearer') {
        $authentication = $_
        $response = Invoke-RestMethod `
            -Method Get `
            -UseBasicParsing `
            -Uri ($env:SYSTEM_COLLECTIONURI + '_apis/projects') `
            -Headers ( Initialize-AzDORestApi -Authentication $authentication )
        $response | Should -Not -Match 'Azure\ DevOps\ Services\ \|\ Sign\ In'
        $response.value.name | Should -Contain $env:SYSTEM_TEAMPROJECT
    }
}
