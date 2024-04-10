# AzDO

This is a collection of Azure DevOps API functions that will eventually be published to PSGallery as a module.

For now, manually import the module file:

```powershell
Import-Module .\src\AzDO.psm1
```

## Development

### Azure DevOps API Functions

For functions that wrap an Azure DevOps API, there are some standard parameters and script blocks that should be used. All functions should include the following parameters and default values as the last ones in the `param` block:

```powershell
[Parameter(ValueFromPipelineByPropertyName = $true)]
[System.Object]$Project = $env:SYSTEM_TEAMPROJECT,
[String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
[String]$Pat = $env:SYSTEM_ACCESSTOKEN
```

The function's `begin` block should start with the following header declaration (with the `ApiVersion` updated as needed):

```powershell
$script:AzApiHeaders = @{
    Headers       = Initialize-AzDORestApi -Pat $Pat
    CollectionUri = $CollectionUri
    ApiVersion    = '6.0'
}
```

The function's `process` block should start with the following code to process the `$Project` parameter if it was passed from the pipeline:

```powershell
. $PSScriptRoot\..\..\private\Get-AzApiProjectName.ps1
$Project = $Project | Get-AzApiProjectName
```

And finally, each invocation of `Invoke-AzDORestApiMethod` should use the following pattern:

```powershell
Invoke-AzDORestApiMethod `
    @script:AzApiHeaders `
    -Method $Method `
    -Project $Project `
    -Endpoint $Endpoint `
    -NoRetry:$NoRetry
```

## PowerShell Module Development

Follow [The PowerShell Best Practices and Style Guide](https://poshcode.gitbooks.io/powershell-practice-and-style/) as much as possible, with the following rules being the most important:

- Use [Approved Verbs](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-5.1) for commands so that PowerShell's built-in ability to autocomplete un-imported functions works.
- Add help comments to **all** functions because each module's wiki is auto-generated from them.

Use the following additional guidelines:

- The module file itself (`.psm1`) should not contain any functions or logic, in most cases, other than a `foreach` loop to dot source all the `.ps1` files and `New-Alias` statements for specific functions.
- Ideally, each module and each of its functions should have a set of [Pester](https://github.com/pester/Pester) unit/integration tests. At the least, any new functions or functionality should have an associated test.
- Create all functions as single `.ps1` files with the same name and without `Export-ModuleMember` statements.
  - The files should be in an appropriate nested `Public` folder that corresponds to its API category.
  - Functions that are used by other functions should be put in either `Utils` or `Private`, depending on their usage.
- The module file (`.psm1`) and each function should have a corresponding `.Tests.ps1` file containing Pester unit/integration tests.
- Don't change any documentation or manifest files; they are automatically populated by the pipeline.

The folder structure should be maintained like the example below:

```console
\MODULEREPODIRECTORY
├───.gitignore
├───azure-pipelines.yml
│
└───ModuleName
    ├───ModuleName.Module.Tests.ps1
    ├───ModuleName.nuspec
    ├───ModuleName.psd1
    ├───ModuleName.psm1
    │
    public
    ├───functionalArea
    │   ├───Verb-Noun.ps1
    │   └───Verb-Noun.Tests.ps1
    │
    private
    ├───Verb-Noun.ps1
    └───Verb-Noun.Tests.ps1
```
