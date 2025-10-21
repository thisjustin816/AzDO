<#
.SYNOPSIS
Registers an Azure Artifacts package feed.

.DESCRIPTION
Registers an Azure Artifacts package feed.

.PARAMETER Name
Name of the feed to register.

.PARAMETER Location
URL of the package feed source.

.PARAMETER Force
Register the source even if it exists.

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to access Azure Artifacts.

.EXAMPLE
Register-AzDOPackageFeed `
    -Name MyFeed `
    -Location https://pkgs.dev.azure.com/MyOrg/_packaging/MyFeed/nuget/v3/index.json

.LINK
https://github.com/microsoft/artifacts-credprovider#environment-variables

.NOTES
N/A
#>

function Register-AzDOPackageFeed {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Location')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('feed')]
        [String[]]$Name,
        [Parameter(ParameterSetName = 'Location', ValueFromPipelineByPropertyName = $true)]
        [String]$Location,
        [Parameter(ParameterSetName = 'Name')]
        [ValidateSet(2, 3)]
        [String]$FeedVersion = 3,
        [Switch]$Force,
        [Parameter(ParameterSetName = 'Name')]
        [String]$Project,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        Set-EnvironmentVariable `
            -Name NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED `
            -Value true `
            -Scope User `
            -Force
        $env:NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED = 'true'
    }

    process {
        foreach ($feedName in $Name) {
            if (!$Location) {
                $orgName = if ($CollectionUri -match 'dev\.azure\.com/([^/]+)') {
                    $matches[1]
                }
                elseif ($CollectionUri -match '([^\.]+)\.visualstudio\.com') {
                    $matches[1]
                }
                else {
                    throw "Unable to extract organization name from CollectionUri: $CollectionUri"
                }
                $fullLocation = "https://pkgs.dev.azure.com/$orgName"

                if (![String]::IsNullOrEmpty($Project)) {
                    $fullLocation += "/$Project"
                }

                $fullLocation += "/_packaging/$feedName/nuget/v$($FeedVersion)"
                if ($FeedVersion -eq 3) {
                    $fullLocation += "/index.json"
                }
            }
            else {
                $fullLocation = $Location
            }

            $endpointConfig = @{
                endpointCredentials = @(
                    @{
                        endpoint = $fullLocation
                        password = $Pat
                    }
                )
            } | ConvertTo-Json -Compress

            $env:ARTIFACTS_CREDENTIALPROVIDER_FEED_ENDPOINTS = $endpointConfig

            # Create PSCredential for NuGet authentication
            $secureString = ConvertTo-SecureString $Pat -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential "PAT", $secureString

            Register-PackageSource `
                -Name $feedName `
                -Location $fullLocation `
                -ProviderName NuGet `
                -Credential $cred `
                -Trusted `
                -Force:$Force
        }

        <# Method for authorizing external feeds. Not needed, but want to keep in case of future use.
        $endpointCredentials = @()
        if ($env:VSS_NUGET_EXTERNAL_FEED_ENDPOINTS) {
            try {
                $endpointCredentials += ( $env:VSS_NUGET_EXTERNAL_FEED_ENDPOINTS | ConvertFrom-Json ) |
                    Select-Object -ExpandProperty endpointCredentials
            }
            catch { }
        }

        $password = $(
            [Convert]::ToBase64String(
                [Text.Encoding]::ASCII.GetBytes($Pat)
            )
        )
        $newEndpoint = [PSCustomObject]@{
            endpoint = $Location
            username = ''
            password = $password
        }
        $newEndpoints = @()
        $newEndpoints += foreach ($endpoint in $endpointCredentials) {
            if ($endpoint -ne $newEndpoint['endpoint']) {
                $endpoint
            }
        }
        $newEndpoints += $newEndpoint
        $endpoints = [PSCustomObject]@{
            endpointCredentials = @($newEndpoints)
        }
        $endpointsJson = $endpoints | ConvertTo-Json | Out-String
        Set-EnvironmentVariable `
            -Name VSS_NUGET_EXTERNAL_FEED_ENDPOINTS `
            -Value $endpointsJson `
            -Scope User `
            -Force
        $env:VSS_NUGET_EXTERNAL_FEED_ENDPOINTS = $endpointsJson
        #>
    }
}
