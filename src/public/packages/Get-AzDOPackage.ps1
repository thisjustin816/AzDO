<#
.SYNOPSIS
Gets the details of a package in an Azure DevOps package feed.

.DESCRIPTION
Gets the details of a package in an Azure DevOps package feed.

.PARAMETER PackageName
Exact name of the package. If nothing is specified, it will return all packages in the feed.

.PARAMETER Version
Version of the package to get details for.

.PARAMETER Feed
Name of the feed that the package is in, or a feed object from Get-AgentPool.

.PARAMETER CollectionUri
https://dev.azure.com/[organization]

.PARAMETER Project
The project that the package feed is scoped to. Leave out for organization-scoped feeds.

.PARAMETER Destination
Downloads the package to the specified directory.

.PARAMETER Pat
A personal access token authorized to access feeds.

.EXAMPLE
Get-AzDOPackageFeed -PackageName ScmFeed | Get-AzDOPackage

.NOTES
N/A

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/artifactspackagetypes/nuget/download%20package
#>
function Get-AzDOPackage {
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param (
        [String[]]$PackageName,
        [Parameter(ParameterSetName = 'List')]
        [Parameter(ParameterSetName = 'Download', Mandatory = $true)]
        [String[]]$Version,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('name')]
        [System.Object]$Feed,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = @(''),
        [Parameter(ParameterSetName = 'Download', Mandatory = $true)]
        [String]$Destination,
        [Switch]$NoRetry,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1-preview.1'
        }
    }

    process {
        . $PSScriptRoot/../../Private/Get-AzDOApiProjectName.ps1
        $Project = $Project | Get-AzDOApiProjectName

        if ($Feed -is [String]) {
            $Feed = Get-AzDOPackageFeed `
                -Name $Feed `
                -Project $Project `
                -CollectionUri $CollectionUri `
                -Pat $Pat `
                -NoRetry:$NoRetry
        }

        $feedPackages = @()
        $feedPackages += foreach ($projectName in $Project) {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -SubDomain 'feeds' `
                -Project $projectName `
                -Endpoint "packaging/Feeds/$($Feed.id)/packages" `
                -Params 'includeDescription=true' `
                -NoRetry:$NoRetry
        }
        if ($PackageName) {
            $namedPackage = foreach ($name in $PackageName) {
                foreach ($package in $feedPackages) {
                    if ($name -eq $package.name) {
                        $package | Add-Member -NotePropertyName feedId -NotePropertyValue $Feed.id
                        $package | Add-Member -NotePropertyName feedName -NotePropertyValue $Feed.name
                        $package
                    }
                }
            }
            foreach ($package in $namedPackage) {
                if ($Version) {
                    foreach ($packageVersion in $Version) {
                        $package.versions = Invoke-AzDORestApiMethod `
                            @script:AzApiHeaders `
                            -Method Get `
                            -SubDomain 'feeds' `
                            -Project $Feed.project.name `
                            -Endpoint "packaging/Feeds/$($Feed.id)/Packages/$($package.id)/versions" `
                            -NoRetry:$NoRetry |
                            Where-Object -Property version -EQ $packageVersion |
                            ForEach-Object -Process {
                                $versionObject = Invoke-AzDORestApiMethod `
                                    @script:AzApiHeaders `
                                    -Method Get `
                                    -SubDomain 'feeds' `
                                    -Project $Feed.project.name `
                                    -Endpoint (
                                        "packaging/Feeds/$($Feed.id)/Packages/$($package.id)/versions/$($_.id)"
                                    ) `
                                    -NoRetry:$NoRetry
                                [PSCustomObject]@{
                                    id                  = $_.id
                                    standardizedVersion = $_.normalizedVersion
                                    version             = $_.version
                                    isLatest            = $_.isLatest
                                    isListed            = $_.isListed
                                    storageId           = $_.storageId
                                    packageDescription  = $versionObject |
                                        Select-Object -ExpandProperty description
                                    views               = $_.views
                                    publishDate         = $_.publishDate
                                    }
                                } |
                                Select-Object -Property @(
                                    'id',
                                    'standardizedVersion',
                                    'version',
                                    'isLatest',
                                    'isListed',
                                    'storageId',
                                    'packageDescription',
                                    'views',
                                    'publishDate'
                                )
                        $package
                        if ($Destination) {
                            $outFile = "$env:TEMP/$($package.name).$($package.versions.standardizedVersion).zip"
                            Invoke-AzDORestApiMethod `
                                @script:AzApiHeaders `
                                -Method Get `
                                -SubDomain 'pkgs' `
                                -Project $Feed.project.name `
                                -Endpoint (
                                    "packaging/feeds/$($Feed.id)/nuget/packages/" +
                                    "$($package.name)/versions/$($package.versions.standardizedVersion)/content"
                                ) `
                                -OutFile $outFile `
                                -NoRetry:$NoRetry
                            $fullDestinationPath = (
                                "$Destination/$($package.name).$($package.versions.standardizedVersion)"
                            )
                            Expand-Archive -Path $outFile -DestinationPath $fullDestinationPath -Force
                            Get-Item -Path $fullDestinationPath
                        }
                    }
                }
                else {
                    $package
                }
            }
        }
        else {
            foreach ($package in $feedPackages) {
                $package | Add-Member -NotePropertyName feedId -NotePropertyValue $Feed.id
                $package | Add-Member -NotePropertyName feedName -NotePropertyValue $Feed.name
                $package
            }
        }
    }
}
