$BuildPSModule = @{
    Name        = 'AzDOCmd'
    Version     = '1.4.0'
    Description = 'A module for interacting with Azure DevOps.'
    Tags        = ('PSEdition_Desktop', 'PSEdition_Core', 'Azure', 'AzureDevOps', 'AzurePipelines')
}

Push-Location -Path $PSScriptRoot
Install-Module -Name JBUtils -Force -AllowClobber
Import-Module -Name "$PSScriptRoot/src/$($BuildPSModule['Name']).psm1" -Force
Install-Module -Name Pester -SkipPublisherCheck -Force
Install-Module -Name PSModuleUtils -Force
if (!$env:GITHUB_ACTIONS) {
    Invoke-PSModuleAnalyzer -Fix
}
Build-PSModule @BuildPSModule
Test-PSModule -Name $BuildPSModule['Name'] -Tag Unit
Pop-Location
