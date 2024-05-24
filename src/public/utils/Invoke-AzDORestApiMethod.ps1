<#
.SYNOPSIS
A wrapper to invoke Azure DevOps API calls.

.DESCRIPTION
A wrapper to invoke Azure DevOps API calls. Authorization is provided by Initialize-AzDORestApi.

.PARAMETER Method
REST method. Supports GET, PATCH, DELETE, PUT, and POST right now.

.PARAMETER CollectionUri
The full Azure DevOps URL of an organization. Can be automatically populated in a pipeline.

.PARAMETER Organization
Azure DevOps organization. Used in place of CollectionUri.

.PARAMETER SubDomain
Subdomain prefix of dev.azure.com that the API requires.

.PARAMETER Project
The project the call will target. Can be automatically populated in a pipeline.

.PARAMETER Endpoint
Everything in between the base URI of the rest call and the parameters.
e.g. VERB https://dev.azure.com/{organization}/{team-project}/_apis/{endpoint}?api-version={version}

.PARAMETER Params
An array of parameter declarations.

.PARAMETER Body
The body of the call if needed.

.PARAMETER OutFile
Path to download the output of the rest call.

.PARAMETER NoRetry
Don't retry failed calls.

.PARAMETER ApiVersion
The version of the API to use.

.EXAMPLE
Invoke-AzDORestApiMethod `
    -Method Get `
    -Organization MyOrg `
    -Endpoint 'work/accountmyworkrecentactivity' `
    -Headers ( Initialize-AzDORestApi -Pat $Pat ) `
    -ApiVersion '5.1'
# GET https://dev.azure.com/MyOrg/_apis/work/accountmyworkrecentactivity?api-version=5.1-preview.2

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Invoke-AzDORestApiMethod {
    [CmdletBinding(DefaultParameterSetName = 'Uri', SupportsShouldProcess = $true)]
    param (
        [ValidateSet('Get', 'Patch', 'Delete', 'Put', 'Post')]
        [Parameter(Mandatory = $true)]
        [string]$Method,
        [Parameter(ParameterSetName = 'Uri')]
        [string]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [Parameter(ParameterSetName = 'Org', Mandatory = $true)]
        [string]$Organization,
        [string]$SubDomain,
        [string]$Project, # = $env:SYSTEM_TEAMPROJECT
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        [string[]]$Params,
        [string]$Body,
        [string]$OutFile,
        [Switch]$NoRetry,
        [string]$ApiVersion = '6.0',
        [hashtable]$Headers = ( Initialize-AzDORestApi )
    )

    $cachedProgressPreference = $ProgressPreference

    if ($PSCmdlet.ParameterSetName -eq 'Org') {
        $CollectionUri = "https://dev.azure.com/$Organization/"
    }
    else {
        $Organization = $CollectionUri.`
            Replace('https://', '').`
            Replace('dev.azure.com', '').`
            Replace('.visualstudio.com', '').`
            Replace('/', '')
    }
    if ($CollectionUri -match '.*\.visualstudio\.com') {
        $CollectionUri = "https://dev.azure.com/$Organization/"
    }
    if ($SubDomain) {
        if ($SubDomain -eq 'azdevopscommerce') {
            $CollectionUri = $CollectionUri.Replace(
                $Organization,
                ( Get-AzDoOrganizationId -CollectionUri $CollectionUri )
            )
        }
        $CollectionUri = $CollectionUri.Replace('dev.azure.com', "$SubDomain.dev.azure.com")
    }
    if ($CollectionUri -notmatch '/$') {
        $CollectionUri += '/'
    }
    $restUri = $CollectionUri

    if (![String]::isNullOrEmpty($Project)) {
        $restUri += [Uri]::EscapeDataString($Project) + '/'
    }

    if ($Params.Length -eq 0) {
        $paramString = "api-version=$ApiVersion"
    }
    else {
        $paramString = (($Params + "api-version=$ApiVersion") -join '&')
    }

    $restUri += ('_apis/' + $Endpoint + '?' + $paramString)
    if ($PSCmdlet.ShouldProcess($restUri, $Method)) {
        Write-Verbose -Message "Method: $Method"
        $restArgs = @{
            Method  = $Method
            Uri     = $restUri
            Headers = $Headers
        }
        switch ($Method) {
            {
                $_ -eq 'Get' -or
                $_ -eq 'Delete'
            } {
                Write-Verbose -Message 'Executing Get or Delete block'
                if ($OutFile) {
                    $restArgs['OutFile'] = $OutFile
                }
            }
            {
                $_ -eq 'Patch' -or
                $_ -eq 'Put' -or
                $_ -eq 'Post'
            } {
                Write-Verbose -Message 'Executing Patch, Put, or Post block.'
                Write-Verbose -Message "Body:`n$Body"
                if ($restUri -match '.*/workitems/.*') {
                    $restArgs['ContentType'] = 'application/json-patch+json'
                }
                else {
                    $restArgs['ContentType'] = 'application/json'
                }
                $restArgs['Body'] = [System.Text.Encoding]::UTF8.GetBytes($Body)
            }
            Default {
                Write-Error -Message 'An unsupported rest method was attempted.'
            }
        }
        $progress = @{
            Activity = $Method
            Status   = $restUri
        }
        if ($VerbosePreference -ne 'SilentlyContinue') {
            Write-Progress @progress
        }
        if ($OutFile) {
            $progress['CurrentOperation'] = "Downloading $OutFile... "
            if ($VerbosePreference -ne 'SilentlyContinue') {
                Write-Progress @progress
            }
            $ProgressPreference = 'SilentlyContinue'
        }
        if ($NoRetry) {
            $delayCounts = @(0)
        }
        else {
            $delayCounts = @(1, 2, 3, 5, 8, 13, 21)
        }
        foreach ($delay in $delayCounts) {
            try {
                $response = $null
                Write-Verbose -Message "$Method $restUri"
                $output = Invoke-RestMethod @restArgs
                $ProgressPreference = $cachedProgressPreference
                if ($output.value) {
                    $output.value
                }
                elseif ($output.count -eq 0) { }
                elseif ($output -match 'Azure DevOps Services | Sign In') {
                    class AzLoginException : Exception {
                        [System.Object]$Response
                        AzLoginException($Message) : base($Message) {
                            $this.Response = [PSCustomObject]@{
                                StatusCode        = [PSCustomObject]@{
                                    value__ = 401
                                }
                                StatusDescription = $Message
                            }
                        }
                    }
                    throw [AzLoginException]::New('Not authorized.')
                }
                else {
                    $output
                }
                break
            }
            catch {
                $response = $_.Exception.Response
                try {
                    $details = ( $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Stop ).message
                }
                catch {
                    $details = $_.ErrorDetails.Message
                }

                if ($response) {
                    $message = "$($response.StatusCode.value__) | $($response.StatusDescription)"
                    if ($details) {
                        $message += " | $details"
                    }
                }
                else {
                    $message = 'Unknown REST error encountered. '
                }
                if (!$NoRetry -and $response.StatusCode.value__ -ne 400) {
                    $message += " | Retrying after $delay seconds..."
                }
                $ProgressPreference = $cachedProgressPreference
                Write-Verbose -Message $message
                $progress['CurrentOperation'] = $message
                if ($VerbosePreference -ne 'SilentlyContinue') {
                    Write-Progress @progress
                }
                if ($OutFile) {
                    $ProgressPreference = 'SilentlyContinue'
                }
                if (!$NoRetry -and $response.StatusCode.value__ -ne 400) {
                    Start-Sleep -Seconds $delay
                }
                else {
                    break
                }
            }
        }
        $ProgressPreference = $cachedProgressPreference
        if ($response) {
            Write-Error -Message "$($response.StatusCode.value__) | $($response.StatusDescription) | $details"
        }
        if ($VerbosePreference -ne 'SilentlyContinue') {
            Write-Progress @progress -Completed
        }
        if ($OutFile) {
            Get-Item -Path $OutFile
        }
    }
}
