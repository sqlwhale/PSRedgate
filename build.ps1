<#
.Description
    Installs and loads all the required modules for the build.
    Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[CmdletBinding()]
param (
    $Task = 'Default'
)
Write-Output "Starting build"

# Grab nuget bits, install modules, set build variables, start build.
Write-Output "  Install Dependent Modules"
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

Write-Output 'Installing BuildHelpers to assist with build process.'
Install-Module 'BuildHelpers' -force -Scope CurrentUser

$null = Set-BuildEnvironment -Path "$PSScriptRoot\PSRedgate" -Force
$environmentDetails = Get-BuildEnvironmentDetail

$modules = @('InvokeBuild', 'PSDeploy', 'BuildHelpers', 'PSScriptAnalyzer', 'Pester')
Write-Output "  Installing and importing dependent modules."
foreach ($module in $modules)
{
    if ($module -notin $environmentDetails.ModulesAvailable.Name)
    {
        Install-Module $module -SkipPublisherCheck -Force -Scope CurrentUser
    }
    if ($module -notin $environmentDetails.ModulesLoaded.Name)
    {
        Import-Module $module -Force
    }
}

Write-Output "  InvokeBuild"
Invoke-Build $Task -Result result

if ($Result.Error)
{
    exit 1
}
else
{
    exit 0
}