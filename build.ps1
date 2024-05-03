#Requires -Modules PSModuleUtils

$BuildPSModule = @{
    Name        = 'AzDOCmd'
    Version     = '0.0.3'
    Description = 'A module for interacting with Azure DevOps.'
    Tags        = ('AzureDevOps', 'DevOps', 'Azure', 'Pipelines')
}

Push-Location -Path $PSScriptRoot
Import-Module -Name "$PSScriptRoot/src/$($BuildPSModule['Name']).psm1" -Force
Build-PSModule @BuildPSModule
Test-PSModule -Name $BuildPSModule['Name'] -Tag Unit
Pop-Location