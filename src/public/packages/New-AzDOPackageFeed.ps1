<#
.SYNOPSIS
Creates a new feed for packages.

.DESCRIPTION
Creates a new feed for packages.

.PARAMETER Name
Name of the feed to create.

.PARAMETER Project
Project that the new feed will be scoped in. If Project is null or empty, the feed is created at the
"organization" scope.

.PARAMETER Pat
Personal access token authorized to administer Azure Artifacts. Defaults to $env:SYSTEM_ACCESSTOKEN for use in
Azure Pipelines.

.EXAMPLE
New-AzDOPackageFeed -FeedName MyFeed

.EXAMPLE
New-AzDOPackageFeed -FeedName MyFeed -Project MyProject

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function New-AzDOPackageFeed {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [Alias('feed')]
        [String[]]$Name,
        [Switch]$NoRetry,
        [String]$Project,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )
    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '5.1-preview.1'
        }
    }

    process {
        foreach ($feed in $Name) {
            $body = @{
                name = $feed
            } | ConvertTo-Json | Out-String

            $newFeed = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Post `
                -SubDomain 'feeds' `
                -Project $Project `
                -Endpoint 'packaging/feeds' `
                -Body $body `
                -NoRetry:$NoRetry
            $location = $CollectionUri
            if ($location[-1] -ne '/') {
                $location += '/'
            }
            if (![String]::IsNullOrEmpty($Project)) {
                $location += "$Project/"
            }
            $location += "_packaging/$($newFeed.name)/nuget/v3/index.json"
            $newFeed | Add-Member `
                -MemberType NoteProperty `
                -Name location `
                -Value $location
            $newFeed
        }
    }
}
