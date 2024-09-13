Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Remove-AzDOPackage.ps1
        . $PSScriptRoot/../Utils/Initialize-AzDORestApi.ps1
        . $PSScriptRoot/Get-AzDOPackage.ps1
        . $PSScriptRoot/../Utils/Invoke-AzDORestApiMethod.ps1

        <#
        .SYNOPSIS
        Add a package to a feed.
        #>
        function Add-TestPackage {
            [CmdletBinding()]
            param (
                [String[]]$FeedName,
                [String]$Project,
                [String[]]$PackageUrl = @(
                    'https://www.nuget.org/api/v2/package/Microsoft.AspNet.WebApi/5.2.6'
                    'https://www.nuget.org/api/v2/package/Microsoft.AspNet.WebApi/5.2.7'
                )
            )

            $cachedProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            $files = foreach ($url in $PackageUrl) {
                $outFile = (
                    "$env:TEMP/microsoft.aspnet.webapi.$(
                        $url.Replace('https://www.nuget.org/api/v2/package/Microsoft.AspNet.WebApi/', '')
                    ).nupkg"
                )
                Invoke-WebRequest `
                    -Uri $url `
                    -UseBasicParsing `
                    -Credential ( Get-PatPSCredential ) `
                    -OutFile $outFile
                Get-Item -Path $outFile
            }

            Invoke-WebRequest `
                -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' `
                -UseBasicParsing `
                -OutFile "$TestDrive/nuget.exe"
            $ProgressPreference = $cachedProgressPreference

            $add = @{
                FeedName = $FeedName
            }
            if ($Project) {
                $add['Project'] = $Project
            }
            $files | Add-AzDOPackage @add
        }
    }

    BeforeEach {
        Mock Set-EnvironmentVariable
    }

    It 'should remove packages in org-scoped feeds' {
        $feed = "TestFeed-Rem-AzDOPackage-$(( New-Guid ).Guid)"
        New-AzDOPackageFeed -Name $feed | Register-AzDOPackageFeed
        Add-TestPackage -FeedName $feed
        Remove-AzDOPackage `
            -PackageName 'Microsoft.AspNet.WebApi' `
            -Version 5.2.6, 5.2.7 `
            -Feed $feed `
            -Provider nuget `
            -Force
        Start-Sleep -Seconds 1
        Get-AzDOPackage `
            -PackageName 'Microsoft.AspNet.WebApi' `
            -Version 5.2.6, 5.2.7 `
            -Feed $feed |
            Should -BeNullOrEmpty
        Remove-AzDOPackageFeed -Name $feed -Force
    }

    It 'should remove packages in project-scoped feeds' {
        $feed = "TestFeed-Rem-AzDOPackage-$(( New-Guid ).Guid)"
        New-AzDOPackageFeed -Name $feed -Project Tools | Register-AzDOPackageFeed
        Add-TestPackage -FeedName $feed -Project Tools
        Remove-AzDOPackage `
            -PackageName 'Microsoft.AspNet.WebApi' `
            -Version 5.2.6, 5.2.7 `
            -Feed $feed `
            -Project Tools `
            -Provider nuget `
            -Force
        Start-Sleep -Seconds 1
        Get-AzDOPackage `
            -PackageName 'Microsoft.AspNet.WebApi' `
            -Version 5.2.6, 5.2.7 `
            -Feed $feed `
            -Project Tools |
            Should -BeNullOrEmpty
        Remove-AzDOPackageFeed -Name $feed -Project Tools -Force
    }
}
