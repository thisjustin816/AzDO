<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Project
Parameter description

.PARAMETER CollectionUri
Parameter description

.PARAMETER Pat
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Connect-AzDO {
    param (
        [String]$Project,
        [String]$CollectionUri,
        [String]$Pat
    )

    $currentAzDOConnection = Get-AzDOConnection
    if ($currentAzDOConnection.PSObject.Properties.Value) {
        Write-Warning -Message 'An existing Azure DevOps connection was found.'
        Write-Host -Object ( $currentAzDOConnection | Format-List | Out-String )
        $response = Read-Host -Prompt 'Would you like to overwrite the existing connection? (y/n)'
    }
    if ($response.ToLower() -ne 'y') {
        return
    }

    while (!$newCollectionUri) {
        $newCollectionUri = if ($CollectionUri) {
            $CollectionUri
        }
        else {
            Read-Host -Prompt (
                "`nPlease enter a Project Collection URI. e.g. " +
                'https://dev.azure.com/[Organization]/'
            )
        }
    }
    Set-EnvironmentVariable -Name 'SYSTEM_COLLECTIONURI' -Value $newCollectionUri -Scope User -Force

    while(!$newProject) {
        $newProject = if ($Project) {
            $Project
        }
        else {
            Read-Host -Prompt "`nPlease enter a default Azure DevOps project"
        }
    }
    Set-EnvironmentVariable -Name 'SYSTEM_TEAMPROJECT' -Value $newProject -Scope User -Force

    while (!$newPat) {
        $newPat = if ($Pat) {
            $Pat
        }
        else {
            Read-Host -Prompt (
                "`n" + 'Please enter an Azure DevOps Personal Access Token (PAT) authorized to access ' +
                'Azure DevOps artifacts. Instructions can be found at:' + "`n`n`t" +
                'https://docs.microsoft.com/en-us/azure/devops/organizations/' +
                'accounts/use-personal-access-tokens-to-authenticate' + "`n`n" +
                'Personal Access Token (PAT)'
            )
        }
    }
    Set-EnvironmentVariable -Name 'SYSTEM_ACCESSTOKEN' -Value $newPat -Scope User -Force

    $currentAzDOConnection = Get-AzDOConnection
    $currentAzDOConnection | Format-List
    $currentAzDOConnection | Test-AzDOConnection
}
