<#
.SYNOPSIS
Gets information about an Azure DevOps package feed.

.DESCRIPTION
Gets information about an Azure DevOps package feed.

.PARAMETER Name
Name of the feed.

.PARAMETER Project
Project that the feed is scoped to. If nothing is specified, it will look for Organization-scoped feeds.

.PARAMETER CollectionUri
https://dev.azure.com/[organization]

.PARAMETER Pat
A personal access token authorized to access feeds.

.EXAMPLE
Get-AzDOPackageFeed -Name PulseFeed, ScmFeed

.NOTES
General notes
#>
function Get-AzDOPackageFeed {
    [CmdletBinding()]
    param (
        [String[]]$Name,
        [String[]]$Project = @(''),
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzRestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '5.1-preview.1'
        }
    }

    process {
        foreach ($projectName in $Project) {
            $allFeeds = @()
            $allFeeds += Invoke-AzRestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -SubDomain 'feeds' `
                -Project $projectName `
                -Endpoint 'packaging/feeds' `
                -NoRetry:$NoRetry
            foreach ($feed in $allFeeds) {
                $feed | Add-Member `
                    -MemberType NoteProperty `
                    -Name location `
                    -Value "$($CollectionUri)/_packaging/$($feed.name)/nuget/v3/index.json"
            }

            $orgName = $CollectionUri -replace 'https://dev.azure.com/', ''
            if (!$allFeeds) {
                $message = 'No feeds found in $orgName '
                if (![String]::isNullOrEmpty($projectName)) {
                    $message += "for project $projectName"
                }
                Write-Warning -Message $message
            }
            elseif ($Name) {
                $namedFeeds = $allFeeds | ForEach-Object -Process {
                    foreach ($feedName in $Name) {
                        if ($feedName -eq $_.name) {
                            $_
                        }
                    }
                }
                if ($namedFeeds) {
                    foreach ($namedFeed in $namedFeeds) {
                        $namedFeed
                    }
                }
                else {
                    $message = "No feeds named $($Name -join ', ') found in $orgName "
                    if (![String]::isNullOrEmpty($projectName)) {
                        $message += "for project $projectName"
                    }
                    Write-Warning -Message $message
                }
            }
            else {
                foreach ($feed in $allFeeds) {
                    $feed
                }
            }
        }
    }
}
