# AzDOCmd

A module for interacting with Azure DevOps.

## Setup

```powershell
Install-Module AzDOCmd
```

## Azure Pipelines variables

`Set-AzPipelinesVariable` writes a non-secret variable for subsequent tasks when
`AGENT_JOBNAME` is set. It leaves the current process environment unchanged and
does nothing outside an agent job.

```powershell
Set-AzPipelinesVariable -Name PackageVersion -Value '1.2.3'
```

Values and names are escaped for the agent logging protocol. `-PassThru` returns
the original name and value; `-WhatIf` writes no command. Setting PATH requires
`-Force`, which still respects `-WhatIf` and `-Confirm`. For appending PATH, the
existing `Add-AzPipelinesPathEntry` command is supplied by JBUtils. Call pipeline
operations explicitly when migrating from PSUtils; JBUtils environment setters
do not propagate changes to subsequent Azure tasks.

This helper has no secret-variable mode. Use the pipeline's secret mechanisms
for credentials and tokens.

## Azure DevOps API Functions

Azure DevOps API wrappers share these parameters. Put them at the end of the
`param` block:

```powershell
[Parameter(ValueFromPipelineByPropertyName = $true)]
[System.Object]$Project = $env:SYSTEM_TEAMPROJECT,
[String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
[String]$Pat = $env:SYSTEM_ACCESSTOKEN
```

Initialize the request headers in `begin` and select the endpoint's API version:

```powershell
$script:AzApiHeaders = @{
    Headers       = Initialize-AzDORestApi -Pat $Pat
    CollectionUri = $CollectionUri
    ApiVersion    = '7.1-preview.2'
}
```

Resolve project objects from pipeline input in `process`:

```powershell
$Project = $Project | Get-AzDOApiProjectName
```

Call the shared REST wrapper:

```powershell
Invoke-AzDORestApiMethod `
    @script:AzApiHeaders `
    -Method $Method `
    -Project $Project `
    -Endpoint $Endpoint `
    -NoRetry:$NoRetry
```

## Development

The source manifest is `src/AzDOCmd.psd1`. Exported functions live under
`src/Public/<api-category>`; private helpers live under `src/Private`. ModuleBuilder
compiles both into a versioned module under `out/AzDOCmd`. Functions call private
helpers directly, so the built module does not depend on source-tree paths.

Tests live under `tests`, mirroring the source layout. The default build runs the
`Unit` tag with Pester 6, including the built module's exported-command contract.
The `WindowsPowerShell` tag verifies the 5.1 transport with mocked responses.
Run it in Windows PowerShell 5.1. Integration tests require a dedicated Azure
DevOps environment and credentials;
run them separately. Unit tests must mock every service call and installation.

Building requires PowerShell 7.4 or newer and PSModuleUtils 5.x. Start a fresh
process after using another Pester major version:

```powershell
Install-Module -Name PSModuleUtils -MinimumVersion 5.0.0 -MaximumVersion 5.999.999 -Scope CurrentUser
./build.ps1
```

The installed module retains its Windows PowerShell 5.1 and PowerShell Core
manifest requirements. A passing build is local verification; it does not validate
live Azure DevOps operations. Publication remains a separate `publish.ps1` step.

Keep one function per source file, use approved verbs, and document public inputs
and outputs in comment-based help. ModuleBuilder derives exports from the public
source files. Update the authored manifest for dependencies and release versions;
Git metadata is applied only to the built manifest.

`Remove-AzDOWorkItemRelation` requires an explicit `-RelationType`. Choose Parent, Child,
Successor, Predecessor, or Related; omitting the parameter does not remove all relations.
