<#
.SYNOPSIS
Gets information on an agent pool (or pools) in Azure Pipelines.

.DESCRIPTION
Gets information on an agent pool (or pools) in Azure Pipelines.

.PARAMETER Name
Name of the pool to get information on. All pools will be returned if nothing is specified.

.PARAMETER Pat
Personal access token authorized to administer builds. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
Get-AzDOAgentPool -Name 'Azure Pipelines'

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/pools/get%20agent%20pools

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>
function Get-AzDOAgentPool {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String[]]$Name,
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '6.1'
        }
    }

    process {
        # TODO: figure out how to get agent pools from projects
        $restArgs = @{
            Method   = 'Get'
            Endpoint = 'distributedtask/pools'
            NoRetry  = $NoRetry
        }

        if ($Name) {
            foreach ($filter in $Name) {
                Write-Verbose -Message "Getting information for the $filter agent pool..."
                $restArgs['Params'] = "poolName=$filter"
                Invoke-AzDORestApiMethod @script:AzApiHeaders @restArgs
            }
        }
        else {
            Write-Verbose -Message 'Getting information for all agent pools...'
            Invoke-AzDORestApiMethod @script:AzApiHeaders @restArgs
        }
    }
}
