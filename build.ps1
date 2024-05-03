$BuildPSModule = @{
    Name        = 'AzDOCmd'
    Version     = '0.0.3'
    Description = 'A module for interacting with Azure DevOps.'
    Tags        = ('AzureDevOps', 'DevOps', 'Azure', 'Pipelines')
}

Push-Location -Path $PSScriptRoot
Install-Module -Name JBUtils
Import-Module -Name "$PSScriptRoot/src/$($BuildPSModule['Name']).psm1" -Force
Install-Module -Name PSModuleUtils
Build-PSModule @BuildPSModule
Test-PSModule -Name $BuildPSModule['Name'] -Tag Unit
Pop-Location