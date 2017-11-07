function Backup-RedgateDatabase
{
    <#
    .SYNOPSIS
    Short description

    .DESCRIPTION
    Long description

    .EXAMPLE
    An example

    .NOTES
    General notes
    #>

    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
    Param (
        [Parameter(Mandatory)]
        # The name of the server containing the database you want to backup
        [string] $SQLServerName,

        [Parameter(Mandatory)]
        # The name of the database you want to backup.
        [string] $DatabaseName,

        [Parameter(Mandatory)]
        [ValidateSet('FULL', 'DIFF', 'LOG')]
        # The location that you want this file backed up.
        [string] $Type,

        [Parameter(Mandatory)]
        # The location that you want this file backed up. This can include any of the dynamic name parts defined by redgate at http://redgateplace.com
        [string] $Disk,

        [Parameter()]
        # The name you would like the file to have on disk. This can include any of the dynamic name parts defined at http://redgateplace.com
        [string] $FileName = '<TYPE>_<DATABASE>_<DATETIME yyyy_mm_dd_hh_nn_ss>.sqb',

        [Parameter()]
        # To make it easier to identify files that are encrypted, I will put a suffix on the file of _ENCRYPTED. The restore command will detect this and auto prompt for password if you don't provide one.
        [switch] $IncludeEncryptionSuffix,

        [parameter()]
        # If you want to encrypt this backup, provide a credential object containing a password to encrypt.
        [System.Management.Automation.PSCredential] $EncryptionCredential,

        [parameter()]
        # If you would like to execute this as a different user and not use integrated auth, pass in a credential object to run as a different user.
        [System.Management.Automation.PSCredential] $Credential,

        [parameter()]
        # This flag indicates that the file is encrypted and we should pass the password to the cmdlet.
        [switch] $Encrypted,

        [Parameter()]
        # If this command should execute the backup, or output the command.
        [switch] $Execute,

        [Parameter()]
        #Specifies the password to be used with encrypted backup files.
        [SecureString] $PASSWORD,

        [Parameter()]
        #Specifies the password file to be used with encrypted backup files.
        [SecureString] $PASSWORDFILE,

        [Parameter()]
        # The description of the backup file
        [string] $DESCRIPTION,

        [Parameter()]
        # The location that you want this file backup copied to. Can be multiples separated by commas.
        $COPYTO,

        [Parameter()]
        [ValidateRange(0, 8)]
        # Specifies the compression level. The default value is 1.
        [int] $COMPRESSION = 1,

        [Parameter()]
        [ValidateRange(1, 120)]
        # The time interval between retries, in seconds, following a failed data-transfer operation.
        [int] $DISKRETRYINTERVAL = 30,

        [Parameter()]
        [ValidateRange(1, 20)]
        # The maximum number of times to retry a failed data-transfer operation.
        [int] $DISKRETRYCOUNT = 10,

        [Parameter()]
        [ValidateRange(2, 32)]
        # Specifies the number of threads to be used to create the backup, where n is an integer between 2 and 32 inclusive.
        [int] $THREADCOUNT = 2,

        [Parameter()]
        [ValidateRange(0, 6)]
        # The maximum number of times to retry a failed data-transfer operation.
        [int] $THREADPRIORITY = 3,

        [Parameter()]
        [ValidateRange(1, 360)]
        # The number of days to retain the backup files before beginning to erase them
        [int] $ERASEFILES,

        [Parameter()]
        [ValidateRange(1, 360)]
        # The number of days to retain the backup files before beginning to erase them
        [int] $ERASEFILES_PRIMARY,

        [Parameter()]
        # Specifies a copy-only backup.
        [switch] $COPY_ONLY,

        [Parameter()]
        # Specifies that files with the same name in the primary backup folder should be overwritten.
        [switch] $INIT,

        [Parameter()]
        #Specifies whether a backup checksum should be created.
        [switch] $CHECKSUM,

        [Parameter()]
        #This option specifies that a full backup should be created if required to take a differential or transaction log backup.
        [switch] $FULLIFREQUIRED,

        [Parameter()]
        #Specifies that a log file should only be created if SQL Backup Pro encounters an error during the backup process, or the backup completes successfully but with warnings.
        [switch] $LOG_ONERROR,

        [Parameter()]
        #Specifies that a log file should only be created if SQL Backup Pro encounters an error during the backup process.
        [switch] $LOG_ONERRORONLY
    )
    BEGIN { }
    PROCESS
    {
        try
        {
            #These are the command line options that are not used as options and are not needed below
            $configuration = @(
                'SQLServerName'
                'Type'
                'DatabaseName'
                'Disk'
                'Encrypted'
                'Credential'
                'EncryptionCredential'
                'Execute'
                'CommandLine'
                'Replication'
            )

            $options = [ordered]@{}

            Write-Verbose "Getting default file locations for server $SQLServerName"
            $defaultTargetLocations = Get-SQLServerDefaultFileLocation -SQLServerName $SQLServerName

            # if you passed a credential object, we'll put it into the password field.
            if ($EncryptionCredential -and -not($options.Contains('PASSWORD')))
            {
                Write-Verbose "Retrieving the password from the encryption object and adding PASSWORD to the options list."
                $options.Add('PASSWORD', $EncryptionCredential.Password)
            }

            if (-not($Encrypted))
            {
                Write-Verbose 'Adding PASSWORD and PASSWORDFILE to the config array so that it will get stripped out.'
                $configuration += 'PASSWORD'
                $configuration += 'PASSWORDFILE'
            }

            Write-Verbose 'Removing unnecessary parameters from our option array'
            $options = $PSBoundParameters.GetEnumerator() | Where-Object {$PSItem.Key -notin $configuration}

            $arguments = Get-RedgateSQLBackupParameter -Parameters $options

            $backupType = $null
            switch ($Type)
            {
                'FULL' { $backupType = 'DATABASE'}
                'DIFF' { $backupType = 'DATABASE'; $arguments += ' DIFFERENTIAL, ' }
                'LOG' { $backupType = 'LOG'}
            }

            if ($Encrypted -and -not($EncryptionCredential -or $PASSWORD -or $PASSWORDFILE))
            {
                Write-Verbose 'We need a credential because this file needs to be encrypted, prompt for a credential object.'
                $EncryptionCredential = (Get-Credential -UserName 'SQL Backup' -Message 'Enter password to encrypt backup file.')
            }


            Write-Verbose 'Defaulting disk to the default backup location for the server if there is no disk location supplied.'
            if (-not($Disk))
            {
                $Disk = $defaultTargetLocations.DefaultBackup
            }


            if (($PASSWORD -or $PASSWORDFILE) -and ($IncludeEncryptionSuffix))
            {
                Write-Verbose 'Adding _ENCRYPTED suffix to file name so that you can detect encryption automatically.'
                $Disk = $Disk.Replace('.sqb', '_ENCRYPTED.sqb')
            }

            $FullPath = " TO DISK = ''$Disk''"

            $backupCommand = "EXEC master..sqlbackup '-SQL ""BACKUP $backupType [$DatabaseName] $FullPath $arguments""'"

            if ($PSCmdlet.ShouldProcess($SQLServerName, $backupCommand))
            {
                $command = "
                    DECLARE @errorcode INT
                          , @sqlerrorcode INT
                    $($backupCommand), @errorcode OUTPUT, @sqlerrorcode OUTPUT;
                    IF (@errorcode >= 500) OR (@sqlerrorcode <> 0)
                    BEGIN
                        RAISERROR ('SQL Backup failed with exit code: %d  SQL error code: %d', 16, 1, @errorcode, @sqlerrorcode)
                    END"

                $params = @{
                    ServerInstance = $SQLServerName
                    Database       = 'master'
                    Query          = $command
                    Credential     = $Credential
                    QueryTimeout   = 7200
                    As             = 'SingleValue'
                }

                #This will output the command in a formatted way
                Write-Verbose ("`n`nBacking up database $DatabaseName from $SQLServerName`n")
                Write-Verbose ($command.Replace(',', "`n,") | Out-String)

                try
                {
                    $result = Invoke-Sqlcmd2 @params -ErrorAction Stop
                }
                catch
                {
                    # exception message comes through like this: Exception calling "Fill" with "1" argument(s): "SQL Backup failed with exit code: 850;  SQL error code: 0"
                    # we want to get the SQL Backup exit code, and the SQL error code.
                    $message = $PSItem.Exception.Message.TrimEnd('"')
                    $message = $message.Split('"')[-1]
                    $errors = $message.Split(';').Trim()
                    foreach ($item in $errors)
                    {
                        $properties = $item.Split(':').Trim()
                        $errorLabel = $properties[0]
                        $errorNumber = $properties[1]
                        if ( $errorLabel -eq 'SQL Backup failed with exit code' -and $errorNumber -ne 0)
                        {
                            Write-Warning "SQL Backup failed with exit code: `n`n$(Get-RedgateSQLBackupError -ErrorNumber $errorNumber)"
                        }
                        elseif ($errorNumber -gt 0)
                        {
                            Write-Warning "$errorLabel : `n`n $errorNumber"
                        }
                    }
                    throw [System.Exception] 'There were errors performing the restore. See warnings above.'
                }
                Write-Verbose ($result | Out-String)
            }
        }
        catch
        {
            Write-Output  $PSItem.Exception | Format-List -Force
            break
        }
    }
    END {}
}