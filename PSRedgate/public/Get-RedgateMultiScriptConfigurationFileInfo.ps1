function Get-RedgateMultiScriptConfigurationFileInfo
{
    <#
    .SYNOPSIS
    This cmdlet allows you to retrieve information from a Multi Script configuration file, such as Saved Credentials, Distribution List, or Database Connections.

    .DESCRIPTION
    This cmdlet is useful for automating actions with Redgate's Multi Script. You often need the ability to pull out values for reuse.

    .EXAMPLE
    Get-RedgateMultiScriptConfigurationFileInfo -ReturnType 'SavedCredentials'

    This allows you to retrieve the list of saved connections from your existing Application.dat file. If you want to use existing credential info this is the easiest way to do it.
    This needs to exist because I can't replicate how Redgate encrypts these passwords and so if you want to use non-integrated auth, you have to set it up once. After that point, you
    can use this to retrieve an existing credential.
    This will default to Application.dat. You can use the -Path parameter to specify a different .dat file.

    Output =>
        version            : 5
        type               : database
        name               : ExampleDB
        server             : SQLEXAMPLE
        integratedSecurity : (True | False)
        username           : (admin) # if not integrated
        savePassword       : (True | False)
        password           : [object]
        passwordValue      : (qaasdfaswoqpweuqtoqirewu/+password+fyi/thisisfake==) # this is the encrypted version of the saved password.
        connectionTimeout  : 15
        protocol           : -1
        packetSize         : 4096
        encrypted          : False
        selected           : True
        cserver            : SQLEXAMPLE\EX1

    .EXAMPLE
    Get-RedgateMultiScriptConfigurationFileInfo -ReturnType 'DistributionLists'

    This will return the named distribution lists you're using in the application. This is so that you can overwrite the same distribution list with the Set-RedgateMultiScriptConfigurationFileInfo.
    This will default to Application.dat. You can use the -Path parameter to specify a different .dat file.

    Output =>
        version   : 2
        type      : databaseList
        name      : Default Distribution List
        databases : databases
        guid      : 1d141f74-4eb7-415d-b9b8-d3f92a7383ff


    .EXAMPLE
    Get-RedgateMultiScriptConfigurationFileInfo -ReturnType 'DatabaseConnections'

    This cmdlet allows you to inspect what servers and databases are in a Multi Script configuration file.
    This will default to Application.dat. You can use the -Path parameter to specify a different .dat file.

    Output =>
        server       | name
        ----------   | --------------
        SQLEXAMPLE1  | WideWorldImporters
        SQLEXAMPLE1  | WideWorldImportersDW
        SQLEXAMPLE1  | master
        SQLEXAMPLE1  | model
        SQLEXAMPLE1  | msdb
        SQLEXAMPLE1  | tempdb

    .EXAMPLE
    Get-RedgateMultiScriptConfigurationFileInfo -FileLocation

    Returns the location on disk of the default Application.dat file to prevent us from having to do this anywhere we need to figure it out. If you pass in a path as well, it will just return that value to you.
    Which admittedly is kind of silly. So don't do that?

    .NOTES
    This functionality is originally inspired by Andy Levy (@andylevy) from feedback that I received from him. Thanks for the contribution.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        # the location of the file that you would like to get information about, defaults to the standard location.
        [string] $Path,

        [Parameter()]
        <#
            Tells the cmdlet to return the location of the Application.dat file. I just wanted to centralize this logic. I realize this could be redundant.
            This is not present in the ReturnType parameter because we need the ability to find the correct file location, even if the file is missing or corrupt
            and it makes the code much cleaner to separate it out.
        #>
        [switch] $FileLocation,

        [Parameter()]
        # The type of information you are trying to retrieve from the config file.
        [ValidateSet('DatabaseConnections', 'DistributionLists', 'SavedCredentials')]
        [string] $ReturnType,

        [Parameter()]
        # tell the cmdlet to return things like the path even if it was unable to verify the file exists.
        [switch] $Force
    )
    BEGIN
    {
        try
        {
            $applicationInfo = Get-RedGateInstallationInfo -ApplicationName 'SQL Multi Script'

            if (-not($applicationInfo))
            {
                Write-Warning 'SQL Multi Script does not appear to be installed on this machine.'
                break
            }

            if (-not($Path))
            {
                Write-Verbose 'A path was not supplied, checking the default location for the Application.dat file.'
                $Path = "$($env:APPDATA)\Red Gate\$($applicationInfo.DisplayName)\Application.dat"
            }

            if ($FileLocation)
            {
                return $Path

            }

            if (-not(Test-Path $Path))
            {
                Write-Warning 'Unable to locate Application.dat file for SQL Multi Script. Please provide a valid location for the file.'
                break
            }

            [xml]$configData = Get-Content $Path
        }
        catch [System.Exception.InvalidCastToXmlDocument]
        {
            Write-Warning 'Unable to parse Application.dat file. Please verify that it is a valid xml file.'
            break
        }
        catch
        {
            Write-Output $PSItem.Exception | Format-List -Force
            break
        }
    }
    PROCESS
    {
        try
        {
            switch ($ReturnType)
            {
                'SavedCredentials'
                {
                    $attributes = @(
                        'version'
                        , 'type'
                        , 'name'
                        , 'server'
                        , 'integratedSecurity'
                        , 'username'
                        , 'savePassword'
                        , 'password'
                        , 'connectionTimeout'
                        , 'protocol'
                        , 'packetSize'
                        , 'encrypted'
                        , 'selected'
                        , 'cserver'
                    )
                    $result = $configData.multiScriptApplication.databaseLists.value.databases.value |
                        Select-Object $attributes -Unique |
                        Select-Object *, @{label = 'passwordValue'; expression = {$PSItem.password.'#text'}}
                }

                'DatabaseConnections'
                {
                    $result = $configData.multiScriptApplication.databaseLists.value.databases.value |
                        Select-Object server, name -Unique
                }
                'DistributionLists'
                {
                    $result = $configData.multiScriptApplication.databaseLists.value
                }
            }

            Write-Output $result
        }
        catch
        {
            Write-Output $PSItem.Exception | Format-List -Force
            break
        }
    }
    END
    {

    }
}
