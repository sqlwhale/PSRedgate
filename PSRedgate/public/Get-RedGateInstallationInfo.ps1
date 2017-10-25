function Get-RedGateInstallationInfo
{
    <#
    .SYNOPSIS
    This cmdlet will return a hash with a list of installed redgate applications on this machine, as well as their locations

    .DESCRIPTION
    This cmdlet is used to locate cmdlets, to prevent relying on the path, as well as determining what versions are available on the machine.

    .EXAMPLE
    Get-RedGateInstallationInfo

    This will return a hash-table filled with the redgate applications installed on this machine.

    .EXAMPLE
    Get-RedGateInstallationInfo -ApplicationName 'SQL Prompt'

    This will return a hash-table containing with the redgate application 'SQL Prompt' installed on this machine.

    .NOTES
    This cmdlet is useful because it prevents us having to affect the user's path, while still making it quick to access
    the command line tool locations.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        # The name of the application you want the information about
        [string] $ApplicationName,

        [Parameter()]
        # This will return only the latest version of an application
        [switch] $LatestVersion
    )
    BEGIN
    {
        $executables = @{
            'SQL Source Control'              = ''
            'SQL Data Generator'              = 'SQLDataGenerator.exe'
            'SSMS Integration Pack Framework' = ''
            'SQL Doc'                         = 'SQLDoc.exe'
            'SQL Test'                        = ''
            'SQL Compare'                     = 'SQLCompare.exe'
            'DLM Automation'                  = ''
            'SQL Dependency Tracker'          = ''
            'SQL Multi Script'                = 'SQLMultiScript.exe'
            'SQL Data Compare'                = 'SQLDataCompare.exe'
            'SSMS Integration Pack'           = ''
            'SQL Search'                      = ''
            'SQL Prompt'                      = ''
        }

        # loading private data from the module manifest
        $private:PrivateData = $MyInvocation.MyCommand.Module.PrivateData
        $installationInformation = $private:PrivateData['installationInformation']
    }
    PROCESS
    {
        try
        {
            if (-not($installationInformation))
            {
                $installationInformation = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
                    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation |
                    Select-Object *, @{Label = "InstallationDate"; Expression = {[datetime]::ParseExact($_.InstallDate, "yyyyMMdd", $null).ToString('MM/dd/yyyy')}} | # casts install date to datetime
                    Select-Object * -ExcludeProperty 'InstallDate' | # remove integer date
                    Select-Object *, @{Label = "ApplicationName"; Expression = {$($_.DisplayName -replace "\d+$", '').Trim()}} | # removes the version number from the application
                    Select-Object *, @{Label = "ExecutableName"; Expression = {$executables[$_.ApplicationName]}} | # appends the exe name to the collection
                    Where-Object Publisher -Like 'Red Gate*'

            }
            $private:PrivateData['installationInformation'] = $installationInformation

            $result = $installationInformation | Where-Object ApplicationName -Like "*$ApplicationName*"

            if ($LatestVersion)
            {
                $result = $result | Group-Object ApplicationName |
                    ForEach-Object {
                    $_.Group |
                        Sort-Object DisplayVersion |
                        Select-Object -Last 1
                }
            }
            Write-Output $result
        }
        catch
        {
            Write-Output  $_.Exception | Format-List -Force
            break
        }
    }
    END
    {
    }
}