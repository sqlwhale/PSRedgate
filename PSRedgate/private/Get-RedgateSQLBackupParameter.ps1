function Get-RedgateSQLBackupParameter
{
    <#
    .SYNOPSIS


    .DESCRIPTION


    .EXAMPLE


    .EXAMPLE

#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        # This cmdlet will take an array of parameters and put them in the format needed for SQL Backup
        $Parameters,

        [parameter()]
        # This cmdlet will take an array of parameters and put them in the format needed for SQL Backup
        [ValidateSet('SQL', 'CommandLine')]
        $OutputFormat = 'SQL'

    )
    BEGIN { }
    PROCESS
    {
        try
        {
            if ($OutputFormat -eq 'SQL')
            {
                #Build the with string so that it can be added to the command
                foreach ($option in $options.GetEnumerator())
                {
                    $paramType = $option.Value.GetType().Name
                    $paramName = $option.Key.ToString().ToUpper()
                    $paramValue = $option.Value.ToString()

                    if ($paramValue)
                    {
                        if (($paramType -eq 'SwitchParameter'))
                        {
                            $with += "$paramName, "
                        }
                        elseif ($paramName -eq 'PASSWORD')
                        {
                            $unsecureString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($option.Value)
                            $with += "PASSWORD = ''$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($unsecureString))'', "
                        }
                        elseif ($paramName -eq 'PASSWORDFILE')
                        {
                            $unsecureString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($option.Value)
                            $with += "PASSWORD = ''FILE:$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($unsecureString))'', "
                        }
                        elseif ($paramName -eq 'COPYTO')
                        {
                            $with += "$paramName = ''$($paramValue -join "'', $paramName = ''")'', "
                        }
                        elseif ($paramType -eq 'String' -and $paramName -notlike 'ERASEFILES*')
                        {
                            if ($paramName.Contains('-'))
                            {
                                $with += "$($paramName.Replace('-', ' ')) ''$paramValue'', "
                            }
                            else
                            {
                                $with += "$paramName = ''$paramValue'', "
                            }
                        }
                        else
                        {
                            $with += "$($paramName.Replace('-','')) = $paramValue, "
                        }
                    }
                }

                #Strip off the trailing comma and space
                if ($options.count -gt 0)
                {
                    $with = $with.TrimEnd(', ')
                }

                Write-Output $with
            }
        }
        catch
        {
            Write-Output $_.Exception | Format-List -Force
            break;
        }
    }
    END { }
}