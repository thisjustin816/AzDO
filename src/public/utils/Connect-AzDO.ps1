<#
.SYNOPSIS
Initializes environment variables needed to connect to Azure DevOps.

.DESCRIPTION
This function initializes environment variables needed to connect to Azure DevOps. If an existing connection is
found, the user is prompted to overwrite the existing connection.

.PARAMETER Project
The default Azure DevOps project to use.

.PARAMETER CollectionUri
The Azure DevOps project collection URI.

.PARAMETER Pat
The Azure DevOps Personal Access Token (PAT) to use.

.EXAMPLE
Connect-AzDO

.NOTES
N/A
#>
function Connect-AzDO {
    param (
        [String]$Project,
        [String]$CollectionUri,
        [String]$Pat
    )

    $currentAzDOConnection = Get-AzDOConnection
    if ($null -ne ( $currentAzDOConnection.PSObject.Properties.Value | Where-Object -FilterScript {$_} )) {
        Write-Warning -Message 'An existing Azure DevOps connection was found.'
        Write-Host -Object ( $currentAzDOConnection | Format-List | Out-String )
        $response = Read-Host -Prompt 'Would you like to overwrite the existing connection? (y/n)'
        if ($response.ToLower() -ne 'y') {
            return
        }
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

    while (!$newProject) {
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
