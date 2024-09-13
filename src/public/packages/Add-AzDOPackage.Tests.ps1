Describe 'Integration Tests' {
    BeforeAll {
        Get-Module -Name PSAzDevOps -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../PSAzDevOps.psm1" -Force
    }

    BeforeEach {
        $PackageUrl = @(
            'https://www.nuget.org/api/v2/package/Microsoft.AspNet.WebApi/5.2.6'
            'https://www.nuget.org/api/v2/package/Microsoft.AspNet.WebApi/5.2.7'
        )

        $cachedProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $script:files = foreach ($url in $PackageUrl) {
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
        $ProgressPreference = $cachedProgressPreference

        Get-Module -Name PSAzDevOps -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../PSAzDevOps.psm1" -Force
    }

    Context 'When there is <_> feed(s)' -ForEach (1, 2) {
        BeforeEach {
            $script:testFeedName = @()
            for ($i = 0; $i -lt $_; $i++) {
                $script:testFeedName += "TestFeed-Add-AzDOPackage-$(( New-Guid ).Guid)"
            }
            $script:testFeed = New-AzDOPackageFeed -Name $script:testFeedName
            $script:packageCount = $script:files.Count * $_
        }

        Context 'and the feed is registered' {
            BeforeEach {
                $script:testFeed | Register-AzDOPackageFeed
            }

            It 'should publish packages to a private az feed' {
                $Script:files |
                    Add-AzDOPackage -FeedName $script:testFeedName |
                    Should -HaveCount $script:packageCount
            }

            Context 'no nuget' {
                BeforeAll {
                    Mock Get-Command -ParameterFilter { $Name -eq 'nuget' } {
                        throw (
                            "The term 'nuget' is not recognized as the name of a " +
                            'cmdlet, function, script file, or operable program.'
                        )
                    }
                }

                It 'should publish packages to a private az feed' {
                    $Script:files |
                        Add-AzDOPackage -FeedName $script:testFeedName |
                        Should -HaveCount $script:packageCount
                }
            }
        }

        Context 'and the feed is not registered' {
            It 'should publish packages to a private az feed' {
                $Script:files |
                    Add-AzDOPackage -FeedName $script:testFeedName |
                    Should -HaveCount $script:packageCount
            }
        }
    }

    AfterEach {
        Remove-Item -Path $script:files -Force -ErrorAction SilentlyContinue
        Get-AzDOPackageFeed -Name $script:testFeedName | ForEach-Object -Process {
            Unregister-PackageSource -Name $_.Name -ErrorAction SilentlyContinue
        }
        Remove-AzDOPackageFeed -Name $script:testFeedName -Force -ErrorAction SilentlyContinue
    }
}