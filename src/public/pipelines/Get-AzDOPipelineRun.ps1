<#
.SYNOPSIS
Gets details for a specific build by ID or user email.

.DESCRIPTION
Gets details for a specific build by ID or user email, with filters for build result, status, and reason.

.PARAMETER BuildId
The ID of the build to get.

.PARAMETER User
The email of the user that the build(s) to get was requested for.

.PARAMETER Result
Only return builds with the specified result.

.PARAMETER Status
Only return builds with the specified status.

.PARAMETER Reason
Only return builds with the specified reason.

.PARAMETER MaxBuilds
The maximum number of builds per project to get. Defaults to 10.

.PARAMETER Project
Project that the build's pipeline resides in.

.PARAMETER Pat
Personal access token authorized to administer builds. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
Get-AzDOPipelineRun -BuildId 111111 -Project MyProject
Gets the build with the specified ID.

.EXAMPLE
Get-AzDOPipelineRun -User myorg@dev.azure.com -Status completed -Reason buildCompletion
Gets 10 completed builds that were triggered by another build's completion started by myorg@dev.azure.com.

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/build/builds/get?view=azure-devops-rest-6.0
#>

function Get-AzDOPipelineRun {
    [CmdletBinding(DefaultParameterSetName = 'BuildId')]
    param (
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true,
            Position = 1,
            ParameterSetName = 'BuildId'
        )]
        [Alias('id')]
        [Int[]]
        $BuildId,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'User'
        )]
        [Alias('requestedFor')]
        [String[]]
        $User,

        [Parameter(
            ParameterSetName = 'User'
        )]
        [ValidateSet(
            'canceled',
            'failed',
            'none',
            'partiallySucceeded',
            'succeeded'
        )]
        [String[]]
        $Result,

        [Parameter(
            ParameterSetName = 'User'
        )]
        [ValidateSet(
            'all',
            'cancelling',
            'completed',
            'inProgress',
            'none',
            'notStarted',
            'postponed'
        )]
        [String[]]
        $Status,

        [Parameter(
            ParameterSetName = 'User'
        )]
        [ValidateSet(
            'all',
            'batchedCI',
            'buildCompletion',
            'checkInShelveset',
            'individualCI',
            'manual',
            'none',
            'pullRequest',
            'resourceTrigger',
            'schedule',
            'scheduleForced',
            'triggered',
            'userCreated',
            'validateShelveset'
        )]
        [String[]]
        $Reason,

        [Parameter(
            ParameterSetName = 'User'
        )]
        [String]
        $MaxBuilds = 10,

        [Switch]
        $NoRetry,

        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [System.Object[]]
        $Project = $env:SYSTEM_TEAMPROJECT,

        [String]
        $CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [string]
        $Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '6.1'
        }
    }

    process {
        . $PSScriptRoot/../../private/Get-AzApiProjectName.ps1
        $Project = $Project | Get-AzApiProjectName

        foreach ($id in $BuildId) {
            foreach ($projectName in $Project) {
                try {
                    $buildInfo = Invoke-AzDORestApiMethod `
                        @script:AzApiHeaders `
                        -Method Get `
                        -Project $projectName `
                        -Endpoint "build/builds/$id" `
                        -NoRetry `
                        -WhatIf:$false `
                        -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Verbose -Message (
                        $_ | Out-String
                    )
                }
                if ($buildInfo) {
                    $buildInfo
                }
                else {
                    Write-Warning -Message "Build $id not found in $projectName."
                }
            }
        }

        foreach ($email in $User) {
            $params = @(
                "requestedFor=$email",
                "`$top=$MaxBuilds",
                'buildQueryOrder=queueTimeDescending'
            )
            if ($Result) {
                $params += "resultFilter=$($Result -join ',')"
            }
            if ($Status) {
                $params += "statusFilter=$($Status -join ',')"
            }
            if ($Reason) {
                $params += "reasonFilter=$($Reason -join ',')"
            }

            foreach ($projectName in $Project) {
                $buildInfo = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -Project $projectName `
                    -Endpoint 'build/builds' `
                    -Params $params `
                    -NoRetry:$NoRetry `
                    -WhatIf:$false

                if ($buildInfo) {
                    $buildInfo
                }
                else {
                    Write-Warning -Message (
                        "$($Result -join '/')/$($Status -join '/')/$($Reason -join '/') " +
                        "builds for $User not found in $projectName."
                    )
                }
            }
        }
    }
}
