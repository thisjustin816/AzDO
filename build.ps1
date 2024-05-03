$BuildPSModule = @{
    Name        = 'AzDOCmd'
    Version     = '0.0.3'
    Description = 'A module for interacting with Azure DevOps.'
    Tags        = ('AzureDevOps', 'DevOps', 'Azure', 'Pipelines')
}

Push-Location -Path $PSScriptRoot
Install-Module -Name JBUtils -Force -AllowClobber
Import-Module -Name "$PSScriptRoot/src/$($BuildPSModule['Name']).psm1" -Force
Install-Module -Name PSModuleUtils -Force
Build-PSModule @BuildPSModule
Test-PSModule -Name $BuildPSModule['Name'] -Tag Unit
Pop-Location