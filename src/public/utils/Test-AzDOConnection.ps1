<#
.SYNOPSIS
Tests various Azure DevOps permissions.

.DESCRIPTION
Tests various Azure DevOps permissions.

.PARAMETER Project
Projects to test project-scoped permissions with.

.PARAMETER CollectionUri
Organization URL.

.PARAMETER Pat
Personal Access Token to test.

.EXAMPLE
Test-AzDOConnection -Project MyProject -Pat examplePat

.NOTES
N/A
#>
function Test-AzDOConnection {
    [CmdletBinding()]
    param (
        [Switch]$NoRetry,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [String[]]$Project = $env:SYSTEM_TEAMPROJECT,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:activity = 'Testing Azure DevOps Permissions'
        $script:permissions = @(
            [PSCustomObject]@{
                Scope      = 'Organization'
                Name       = 'Agents'
                Authorized = $false
            }
            [PSCustomObject]@{
                Scope      = 'Organization'
                Name       = 'Organization Info'
                Authorized = $false
            }
            [PSCustomObject]@{
                Scope      = 'Organization'
                Name       = 'Packages'
                Authorized = $false
            }
        )

        $script:restParams = @{
            NoRetry       = $NoRetry
            CollectionUri = $CollectionUri
            Pat           = $Pat
            ErrorAction   = 'SilentlyContinue'
        }

        foreach ($orgPermission in $script:permissions) {
            $status = (
                'Testing ' +
                $CollectionUri.Split('/').Where({ $_ })[-1] +
                '/' +
                $orgPermission.Name +
                ' permissions...'
            )
            Write-Progress -Activity $script:activity -Status $status
            $authorizedPermission = $null
            $authorizedPermission = try {
                switch ($orgPermission.Name) {
                    'Agents' { Get-AzDOAgentPool @script:restParams -Name 'Azure Pipelines' }
                    'Organization Info' { Get-AzDOProject @script:restParams }
                    'Packages' { Get-AzDOPackageFeed @script:restParams }
                }
            }
            catch {
                Write-Verbose -Message $_.Exception.Message
            }
            if ($authorizedPermission) {
                $orgPermission.Authorized = $true
            }
        }
    }

    process {
        foreach ($scope in $Project) {
            $projectPermissions = @(
                [PSCustomObject]@{
                    Scope      = $scope
                    Name       = 'Packages'
                    Authorized = $false
                }
                [PSCustomObject]@{
                    Scope      = $scope
                    Name       = 'Pipelines'
                    Authorized = $false
                }
                [PSCustomObject]@{
                    Scope      = $scope
                    Name       = 'Repositories'
                    Authorized = $false
                }
            )

            $script:restParams['Project'] = $scope

            foreach ($permission in $projectPermissions) {
                $status = "Testing $($permission.Scope)/$($permission.Name) permissions..."
                Write-Progress -Activity $script:activity -Status $status
                $authorizedPermission = $null
                $authorizedPermission = try {
                    switch ($permission.Name) {
                        'Packages' { Get-AzDOPackageFeed @script:restParams }
                        'Pipelines' { Get-AzDOPipeline @script:restParams }
                        'Repositories' { ( Get-AzDORepository @script:restParams ).id }
                    }
                }
                catch {
                    Write-Verbose -Message $_.Exception.Message
                }
                if ($authorizedPermission) {
                    $permission.Authorized = $true
                }
            }

            $script:permissions += $projectPermissions
        }
        Write-Progress -Activity $script:activity -Completed
    }

    end {
        $script:permissions
        $failedPermissions = @( $script:permissions | Where-Object -Property Authorized -NE $true )
        if ($failedPermissions) {
            Write-Error -Message (
                "Not authorized for $($failedPermissions.Count)/$($script:permissions.Count) permissions!"
            )
        }
    }
}