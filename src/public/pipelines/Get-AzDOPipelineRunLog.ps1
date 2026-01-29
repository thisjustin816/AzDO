<#
.SYNOPSIS
Gets all logs from a pipeline run and combines them.

.DESCRIPTION
Gets all logs from a pipeline run and combines them.

.PARAMETER BuildId
ID of the pipeline run to get logs from.

.PARAMETER Destination
Directory to create the log file in. Outputs to the console if not specified.

.PARAMETER NoRetry
Don't retry the API call if it fails.

.PARAMETER Project
Project that the build's pipeline resides in.

.PARAMETER CollectionUri
The Project Collection URI (https://dev.azure.com/[organization])

.PARAMETER Pat
An Azure DevOps Personal Access Token authorized to view pipelines.

.EXAMPLE
Get-AzDOPipelineRunLog -BuildId 11111 -Project Tools `
    -Destination $env:USERPROFILE/Downloads

.EXAMPLE
Get-AzDOPipelineRun -BuildId 11111 -Project Tools |
    Get-AzDOPipelineRunLog

.NOTES
N/A

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/build/builds/get-build-logs
#>
function Get-AzDOPipelineRunLog {
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [String[]]
        $BuildId = $env:BUILD_BUILDID,

        [String]
        $Destination,

        [Switch]
        $NoRetry,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]
        $Project = $env:SYSTEM_TEAMPROJECT,

        [String]
        $CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [String]
        $Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = Initialize-AzDORestApi -Pat $Pat
        $script:AzApiHeaders['CollectionUri'] = $CollectionUri
        $script:AzApiHeaders['ApiVersion'] = '6.1'
    }

    process {
        . "$PSScriptRoot/../../private/Get-AzDOApiProjectName.ps1"
        $Project = $Project | Get-AzDOApiProjectName

        $progress = @{
            Activity = 'Getting Pipeline Run Logs'
        }

        foreach ($id in $BuildId) {
            $logsRestCall = @{
                Method   = 'Get'
                Endpoint = "build/builds/$id/logs"
                NoRetry  = $NoRetry
                Project  = $Project
            }

            if ($Destination) {
                $progress['Status'] = "Getting run $id..."
                $buildParams = @{
                    BuildId       = $id
                    NoRetry       = $NoRetry
                    Project       = $Project
                    CollectionUri = $CollectionUri
                    Pat           = $Pat
                }

                Write-Progress @progress -CurrentOperation 'Getting run info'
                $build = Get-AzDOPipelineRun @buildParams

                $progress['Status'] = "Getting run $id logs..."
                Write-Progress @progress -CurrentOperation 'Downloading log archive'
                $outfile = New-TemporaryFile
                $null = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    @logsRestCall `
                    -Params @{'$format' = 'zip' } `
                    -OutFile $outfile.FullName

                Write-Progress @progress -CurrentOperation 'Staging log archive'
                $outfile | Copy-Item `
                    -Destination "$Destination/$($build.buildNumber.Replace(' ', '_'))_logs.zip" `
                    -Force `
                    -PassThru
            }
            else {
                $progress['Status'] = "Getting run $id logs..."
                Write-Progress @progress -CurrentOperation 'Getting log info'
                $logs = Invoke-AzDORestApiMethod @script:AzApiHeaders @logsRestCall

                foreach ($log in $logs) {
                    Write-Progress `
                        @progress `
                        -CurrentOperation "Downloading $($log.id)/$($logs.Count)" `
                        -PercentComplete (($log.id / $logs.Count) * 100)

                    foreach ($delay in .1, .2, .3, .5, .8, 1.3) {
                        try {
                            Invoke-RestMethod `
                                -Method Get `
                                -UseBasicParsing `
                                -Uri $log.url `
                                -Headers $script:AzApiHeaders['Headers']
                            break
                        }
                        catch {
                            Write-Verbose -Message $_
                            Write-Verbose -Message `
                                "Delaying for $delay seconds before trying again."
                            Start-Sleep -Seconds $delay
                        }
                    }
                }
            }
        }

        Write-Progress @progress -Completed
    }
}
