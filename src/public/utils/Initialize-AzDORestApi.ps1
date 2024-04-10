[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidLongLines', '')]
[CmdletBinding()]
param ()

<#
.SYNOPSIS
Creates authorization headers for an Azure DevOps REST API call.

.DESCRIPTION
Creates authorization headers for an Azure DevOps REST API call.

.PARAMETER User
Deprecated. Not used for API calls.

.PARAMETER Pat
Personal access token authorized for the call being made. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.PARAMETER Authentication
Choose Basic or Bearer authentication. Note that Bearer authentication will disregard Pat and CollectionUri and
use the current Azure context returned from Get-AzContext.

.EXAMPLE
$headers = Initialize-AzDORestApi

.LINK
https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?toc=%2Fazure%2Fdevops%2Fmarketplace-extensibility%2Ftoc.json&view=azure-devops&tabs=Windows#use-a-pat

.LINK
https://dotnetdevlife.wordpress.com/2020/02/19/get-bearer-token-from-azure-powershell/

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Initialize-AzDORestApi {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [String]$User,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN,
        [ValidateSet('Basic', 'Bearer')]
        [String]$Authentication = 'Basic'
    )

    if ($User) {
        Write-Verbose -Message 'A User was specified but is not needed and will not be used.'
    }

    if ($Authentication -eq 'Basic') {
        $base64EncodedToken = $(
            [Convert]::ToBase64String(
                [Text.Encoding]::ASCII.GetBytes(":$Pat")
            )
        )

        @{
            Authorization = "Basic $base64EncodedToken"
        }
    }
    else {
        try {
            $tenantId = ( Get-AzContext -ErrorAction Stop ).Subscription.TenantId
        }
        catch {
            Connect-AzAccount
            $tenantId = ( Get-AzContext -ErrorAction Stop ).Subscription.TenantId
        }

        $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
        Write-Verbose -Message 'Current Azure Context:'
        Write-Verbose -Message $azureRmProfile.DefaultContextKey.ToString()
        Write-Verbose -Message (
            $azureRmProfile.Contexts.Keys | Where-Object -FilterScript { $_ -notmatch 'Concierge' } | Out-String
        )

        $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
        $token = $profileClient.AcquireAccessToken($tenantId).AccessToken
        if ($token) {
            Write-Verbose -Message 'Azure AD bearer token generated!'
        }
        else {
            Write-Error -Message 'Azure AD bearer token unable to be generated.'
        }

        @{
            Accept        = 'application/json'
            Authorization = "Bearer $token"
        }
    }
}
