<#
.SYNOPSIS
Adds a NuGet package to a private feed.

.DESCRIPTION
Adds a NuGet package to a private feed.

.PARAMETER FilePath
Path to the NuGet package file.

.PARAMETER FeedName
Name of the feed to publish to.

.PARAMETER Project
The project that the package feed is scoped to. Leave out for organization-scoped feeds.

.PARAMETER CollectionUri
https://dev.azure.com/[organization]

.PARAMETER Pat
A personal access token authorized to push to feeds.

.EXAMPLE
Add-AzDOPackage -FilePath packagename.1.0.0.nupkg -FeedName MyFeed

.NOTES
N/A
#>
function Add-AzDOPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [String[]]$FilePath,
        [Parameter(Mandatory = $true)]
        [String[]]$FeedName,
        [String]$Project,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        # Workaround for using variables only in a ForEach-Object block
        Write-Information -MessageData (($Project + $CollectionUri + $Pat) -replace '.*', '' )

        $nuget = try {
            ( Get-Command -Name nuget ).Name
        }
        catch {
            ( Install-NugetCli ).Name
        }

        foreach ($feed in $FeedName) {
            try {
                Get-PackageSource -Name $feed -ErrorAction Stop | Out-Null
            }
            catch {
                if ( Get-AzDOPackageFeed -Name $feed -Project $Project -CollectionUri $CollectionUri -Pat $Pat ) {
                    $null = Register-AzDOPackageFeed -Name $feed -Project $Project -Force -Pat $Pat
                }
                else {
                    throw $_
                }
            }

            Start-CliProcess `
                -FilePath $nuget `
                -ArgumentList (
                    'sources', 'Update',
                    '-Name', $feed,
                    '-UserName', $Pat,
                    '-Password', $Pat
                ) `
                -WorkingDirectory $PWD
        }
    }

    process {
        foreach ($feed in $FeedName) {
            Get-Item -Path $FilePath |
                ForEach-Object -Process {
                    Start-CliProcess `
                        -FilePath $nuget `
                        -ArgumentList (
                            'push',
                            '-Source',
                            $feed,
                            '-ApiKey',
                            $Pat,
                            $_.FullName
                        ) `
                        -WorkingDirectory $PWD

                    $name, $version = $_.BaseName -split '(?<=[^\d])\.(?=\d)'
                    $uploadedPackage = Get-AzDOPackage `
                        -Feed $feed `
                        -PackageName $name `
                        -Version $version `
                        -CollectionUri $CollectionUri `
                        -Project $Project `
                        -Pat $Pat
                    if ($uploadedPackage) {
                        $uploadedPackage
                    }
                    else {
                        throw "$name upload unsuccessful."
                    }
                }
        }
    }
}
