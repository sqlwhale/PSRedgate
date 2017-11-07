function Set-RedgateMultiScriptConfigurationFileInfo
{
    <#
    .SYNOPSIS
    This cmdlet is used to generate a new Application.dat file or a Distribution List for Redgate's SQL Multi Script application.

    .DESCRIPTION
    We have the need to dynamically generate configuration files for Redgate's SQL Multi Script because sometimes environments change and
    manually having to configure the application can be difficult and time consuming. This cmdlet will allow you to quickly and easily create
    a config with many servers or databases in them. This cmdlet is designed to work will with dbatools (www.dbatools.io) using their Get-DBADatabase
    cmdlet.

    .EXAMPLE


#>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'IntegratedSecurity')]
    param (
        # the location that you want the file to be written, by default will overwrite your current Application.dat
        [string]$Path,

        [Parameter()]
        # the distribution list that you would like to modify. If none is provided, it will default to the first one.
        [string]$DistributionList,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        # the instance that you would like to create a connection to.
        [string]$SQLInstance,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        # database name. It comes back as name from dbatools for some reason.
        [Alias('DatabaseName', 'Database')]
        [string]$Name,

        [Parameter()]
        [ValidateSet('ApplicationConfig', 'DistributionList')]
        # This will tell the cmdlet whether you want to load a pre-generated list of files, or change your default file.
        [string]$As = 'DistributionList',

        [Parameter(ParameterSetName = 'IntegratedSecurity')]
        #if passed, then use integrated, and don't require a username and password.
        [switch]$IntegratedSecurity,

        [Parameter(Mandatory, ParameterSetName = 'SQLAuth')]
        # the UserName to supply to every connection that is created using this method
        [string]$UserName,

        [Parameter(Mandatory, ParameterSetName = 'SQLAuth')]
        # the password for the user name specified
        [string]$encryptedKey,

        [Parameter(ParameterSetName = 'AutoSQLAuth')]
        # tells the cmdlet that you would like to use a set of already existing credentials.
        [switch]$PromptForCredentials,

        [Parameter()]
        # This is a collection that you can pass in to overwrite the defaults.
        [System.Collections.HashTable] $ApplicationParameters,

        [Parameter()]
        # required to overwrite an existing file.
        [switch]$Force
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
                $Path = Get-RedgateMultiScriptConfigurationFileInfo -FileLocation
            }

            $existingConfigFile = Test-Path $Path

            if ($PromptForCredentials)
            {
                if ($existingConfigFile)
                {
                    $result = Get-RedgateMultiScriptConfigurationFileInfo -ReturnType 'SavedCredentials'
                    Where-Object integratedSecurity -eq 'False' |
                        Select-Object 'username', 'passwordValue' -Unique |
                        Out-GridView -OutputMode Single -Title 'Select an embedded credential that you would like to use'

                    $UserName = $result.username
                    $encryptedKey = $result.passwordValue
                }
                else
                {
                    Write-Warning "Unable to retrieve stored credentials, the $Path file does not exist. Create a starting file with the credentials for this to work."
                }
            }

            if (($DistributionList))
            {
                $guid = [guid]::NewGuid()
            }
            elseif ($existingConfigFile)
            {
                $result = Get-RedgateMultiScriptConfigurationFileInfo -ReturnType 'DistributionLists' |
                    Select-Object -First 1
                $DistributionList = $result.name
                $guid = $result.guid
            }
            else
            {
                $DistributionList = 'Default Distribution List'
                $guid = [guid]::NewGuid()
            }



            $fileContent = "<?xml version=`"1.0`" encoding=`"utf-16`" standalone=`"yes`"?>"

            if ($As -eq 'ApplicationConfig')
            {
                Write-Verbose 'Creating application configuration file.'
                $defaultParameters = @{
                    executionTimeout           = 0
                    batchSeparator             = 'GO'
                    displayFormat              = 0
                    maximumNonXMLDataRetrieved = 65535
                    maximumXMLDataRetrieved    = 2097152
                    maximumCharactersPerColumn = 256
                    maximumParallelServers     = 5
                    useParallelExecution       = 'True'
                    scriptEncoding             = 1252
                }

                # this will overwrite any of the values in the hash above if someone specified something they want to overwrite.
                if ($ApplicationParameters)
                {
                    Write-Verbose 'Overwriting default values with values from -ApplicationParameters'
                    $ApplicationParameters.GetEnumerator() | ForEach-Object {
                        $defaultParameters.item($PSItem.Name) = $PSItem.Value
                    }
                }


                Write-Verbose 'Generating list of application options.'
                $fileContent += "<multiScriptApplication version=`"4`" type=`"multiScriptApplication`">
                                    <addedServers type=`"List_server`" version=`"1`" />
                                    <applicationOptions version=`"4`" type=`"applicationOptions`">"
                foreach ($parameter in $defaultParameters.GetEnumerator())
                {
                    $fileContent += "<$($PSItem.Name)>$($PSItem.Value)</$($PSItem.Name)>"
                }
                $fileContent += '</applicationOptions>
                                 <currentProject />'
            }
            elseif ($As -eq 'DistributionList')
            {
                $fileContent += "<databaseListsFile version=`"1`" type=`"databaseListsFile`"> "

            }

            $fileContent += "
              <databaseLists type=`"List_databaseList`" version=`"1`">
                <value version=`"2`" type=`"databaseList`">
                  <name>$DistributionList</name>
                  <databases type=`"BindingList_database`" version=`"1`">"
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
            if ($IntegratedSecurity)
            {
                $fileContent += "<value version=`"5`" type=`"database`">
                <name>$Name</name>
                <server>$SQLInstance</server>
                <integratedSecurity>True</integratedSecurity>
                <connectionTimeout>15</connectionTimeout>
                <protocol>-1</protocol>
                <packetSize>4096</packetSize>
                <encrypted>False</encrypted>
                <selected>True</selected>
                <cserver>$SQLInstance</cserver>
                </value>"
            }
            else
            {
                $fileContent += "
                <value version=`"5`" type=`"database`">
                <name>$Name</name>
                <server>$SQLInstance</server>
                <integratedSecurity>False</integratedSecurity>
                <username>$UserName</username>
                <savePassword>True</savePassword>
                <password encrypted=`"1`">$encryptedKey</password>
                <connectionTimeout>15</connectionTimeout>
                <protocol>-1</protocol>
                <packetSize>4096</packetSize>
                <encrypted>False</encrypted>
                <selected>True</selected>
                <cserver>$SQLInstance</cserver>
                </value>"
            }


        }
        catch
        {
            Write-Output $PSItem.Exception | Format-List -Force
            break
        }
    }
    END
    {
        try
        {

            $fileContent += " </databases>
                            <guid>$guid</guid>
                            </value>
                            </databaseLists>"


            if ($As -eq 'ApplicationConfig')
            {
                $fileContent += "<autoCloseSaveAllResultsProgressDialog>False</autoCloseSaveAllResultsProgressDialog>
                            </multiScriptApplication>"
            }
            elseif ($As -eq 'DistributionList')
            {
                $fileContent += '</databaseListsFile>'
            }

            if ($Path)
            {
                if (-not(Test-Path $Path))
                {
                    Write-Verbose "Creating file for config file or distribution list."
                    New-Item $Path -ItemType File
                }

                Set-Content -Value $fileContent -LiteralPath $Path
            }
            else
            {
                Write-Output $fileContent
            }
        }
        catch
        {
            Write-Output $PSItem.Exception | Format-List -Force
            break

        }
    }
}