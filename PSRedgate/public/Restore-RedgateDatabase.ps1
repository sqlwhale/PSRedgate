function Restore-RedgateDatabase
{
    <#
    .SYNOPSIS
        This cmdlet is a wrapper for the stored procedure master..sqlbackup. Instead of trying to handle remoting and talking to the command line tool, this cmdlet will
        allow you to simply pass in parameters to execute restores on your servers.

    .DESCRIPTION
        Using this cmdlet, you can perform all of the normal operations that you would do using the redgate sql backup ui, or would write manually using SSMS.

    .EXAMPLE
        An example

    .NOTES
        General notes
    #>


    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
    Param (
        [Parameter(Mandatory)]
        # The name of the database you want to backup.
        [string] $TargetSQLServerName,

        [Parameter()]
        # The name of the server containing the database you want to backup. Only needed if you are renaming the database and need to find out the file names.
        [string] $SourceSQLServerName,

        [Parameter(Mandatory)]
        # The location that you want this file backed up.
        [string] $DatabaseName,

        [Parameter(Mandatory)]
        [ValidateSet('LATEST_FULL', 'LATEST_DIFF', 'LATEST_ALL', 'LOG')]
        # The location that you want this file backed up.
        [string] $Type,

        [Parameter()]
        # This variable should be passed when you want to rename the database
        [string] $RestoreAs,

        [Parameter(Mandatory, ParameterSetName = 'FullPath')]
        # The file you would like to use in the restore command
        [string[]] $Disk,

        [Parameter(Mandatory, ParameterSetName = 'RelativePath')]
        # The location that you want these restores to be pulled from
        [string] $FileLocation,

        [Parameter()]
        # If this command should be built for the stored procedure
        [switch] $CommandLine,

        [Parameter()]
        # If this command should execute the backup, or output the command.
        [switch] $Execute,

        [Parameter()]
        # If this command use the replication location to find the backup files.
        [switch] $Replication,

        [parameter()]
        # If the backup is encrypted, pass a credential object with the password needed to decrypt the file.
        [System.Management.Automation.PSCredential] $DecryptionCredential,

        [parameter()]
        # If you would like to execute this as a different user and not use integrated auth, pass in a credential object to run as a different user.
        [System.Management.Automation.PSCredential] $Credential,

        [parameter()]
        # This flag indicates that the file is encrypted and we should pass the password to the cmdlet. This requires all files passed in the pipeline to be encrypted.
        [switch] $Encrypted,

        [Parameter()]
        # This parameter is needed if there is no way to determine what the logical name of a database is and you want to use $RestoreAs. This is the logical name needed to move the Data file.
        [string] $DatabaseDataFileLogicalName,

        [Parameter()]
        # This parameter is needed if there is no way to determine what the logical name of a database is and you want to use $RestoreAs. This is the logical name needed to move the Log file.
        [string] $DatabaseLogFileLogicalName,

        [Parameter()]
        # This is the location where you would like to put an undo file if you are going to create one.
        [string] $StandbyLocation,

        [Parameter()]
        [ValidateSet('NO_INFOMSGS' , 'ALL_ERRORMSGS' , 'TABLOCK' , 'PHYSICAL_ONLY' , 'DATA_PURITY' , 'EXTENDED_LOGICAL_CHECKS' , 'VERBOSE' )]
        #Runs a database integrity check (DBCC CHECKDB) on the database once the restore is complete. This checks the logical and physical integrity of all the objects in the specified database. CHECKDB cannot be used in conjunction with NORECOVERY.
        [string] $CHECKDB ,

        [Parameter()]
        #By default, if the backup process included WITH CHECKSUM the backup checksum and any page checksums are validated on restore. If the backup does not include a backup checksum, any page checksums will not be validated.
        [switch] $CHECKSUM ,

        [Parameter()]
        #Specify NO_CHECKSUM to disable default validation of checksums. If you specify CHECKSUM, the backup checksum and any page checksums will be validated as by default, but if the backup does not include a backup checksum, an error is returned.
        [switch] $NO_CHECKSUM ,

        [Parameter()]
        #specifies that the RESTORE process should continue after an error is encountered, restoring what it can. This is the default behavior for RESTORE VERIFYONLY (see VERIFY in The BACKUP command). The RESTORE VERIFYONLY process then reports all errors it has encountered.
        [switch] $CONTINUE_AFTER_ERROR ,

        [Parameter()]
        #specifies that the RESTORE process should stop if an error is encountered. This is the default behavior for RESTORE.
        [switch] $STOP_ON_ERROR,

        [Parameter()]
        #Kills any existing connections to the database before starting the restore. Restoring to an existing database will fail if there are any connections to the database.
        [switch] $DISCONNECT_EXISTING ,

        [Parameter()]
        [ValidateRange(1, 30000)]
        #Specifies a minimum age, in seconds, for transaction log backups. Only backups older than the specified age will be restored. This is useful if you are log shipping to maintain a standby database and want to delay restores to that database, for example, to help protect against corrupt or erroneous data.
        [int] $DELAY,

        [Parameter()]
        [ValidateRange(1, 120)]
        # specifies the time interval between retries, in seconds, following a failed data-transfer operation (reading or moving a backup file). If you omit this keyword, the default value of 30 seconds is used.
        [int] $DISKRETRYINTERVAL = 30,

        [Parameter()]
        [ValidateRange(1, 50)]
        # specifies the maximum number of times to retry a failed data-transfer operation (reading or moving a backup file). If you omit this keyword, the default value of 10 is used.
        [int] $DISKRETRYCOUNT = 10,

        [Parameter()]
        #Drops the database after the restore process (and database integrity check if used in conjunction with CHECKDB). The restored database is removed from the SQL Server instance regardless of whether any errors or warnings were returned.
        [switch] $DROPDB ,

        [Parameter()]
        #Drops the database if the restore completed successfully. When used in conjunction with CHECKDB, drops the database if the restore completed successfully and the database integrity check completed without errors or warnings.
        [switch] $DROPDBIFSUCCESSFUL ,

        [Parameter()]
        #Specifies the number of existing SQL Backup backups to be deleted from the MOVETO folder. This is useful for managing the number of backups in the MOVETO folder when log shipping. Number is days, number followed by h is hours, number followed by b is number to keep.
        [string] $ERASEFILES,

        [Parameter()]
        #Manages deletion of existing SQL Backup backups from remote MOVETO folders. This is useful for managing the number of files in the MOVETO folder when log shipping.
        [int] $ERASEFILES_REMOTE ,

        [Parameter()]
        #Manages deletion of existing SQL Backup backups from the DISK location. If multiple DISK locations are specified, the setting is applied to each folder. The backup files are deleted only if the backup process completes successfully.
        [int] $ERASEFILES_PRIMARY,

        [Parameter()]
        #Manages deletion of existing SQL Backup backups from the MOVETO folder.
        [int] $ERASEFILES_SECONDARY,

        [Parameter()]
        #Use in conjunction with ERASEFILES. Specifies whether backup files are to be deleted from the MOVETO folder. Specify the sum of the values that correspond to the options you require. 1   Delete backup files in the MOVETO folder if they are older than the number of days or hours specified in ERASEFILES. 2  Do not delete backup files in the MOVETO folder that are older than the number of days or hours specified in ERASEFILES if they have the ARCHIVE flag set.
        [int] $FILEOPTIONS ,

        [Parameter()]
        #Specifies that Change Data Capture settings are to be retained when a database or log is restored to another server. This option cannot be included with NORECOVERY.
        [switch] $KEEP_CDC ,

        [Parameter()]
        #This option is for use when log shipping is used in conjunction with replication. Specifies that replication settings are to be retained when a database or log is restored to a standby server. This option cannot be included with NORECOVERY.
        [switch] $KEEP_REPLICATION ,

        [Parameter()]
        #Specifies that a log file should only be created if SQL Backup Pro encounters an error during the restore process, or the restore completes successfully but with warnings. Use this option if you want to restrict the number of log files created by your restore processes, but maintain log information whenever warnings or errors occur. This argument controls the creation of log files on disk only;
        [switch] $LOG_ONERROR ,

        [Parameter()]
        #Specifies that a log file should only be created if SQL Backup Pro encounters an error during the restore process. Use this option if you want to restrict the number of log files created by your restore processes, but maintain log information whenever errors occur. This argument controls the creation of log files on disk only;
        [switch] $LOG_ONERRORONLY ,

        [Parameter()]
        #Specifies that a copy of the log file is to be saved.
        [string] $LOGTO ,

        [Parameter()]
        #Specifies that the outcome of the restore operation is emailed to one or more users; the email includes the contents of the log file.
        [string] $MAILTO,

        [Parameter()]
        #Specifies that SQL Backup Pro should not include the contents of the log file in the email. An email will still be sent to notify the specified recipients of success and/or failure, depending on which MAILTO parameter has been specified.
        [switch] $MAILTO_NOLOG ,

        [Parameter()]
        #Specifies that that the outcome of the restore operation is emailed to one or more users if SQL Backup Pro encounters an error during the restore process or the restore process completes successfully but with warnings. The email includes the contents of the log file.
        [string] $MAILTO_ONERROR ,

        [Parameter()]
        #Specifies that that the outcome of the restore operation is emailed to one or more users if SQL Backup Pro encounters an error during the restore process.
        [string] $MAILTO_ONERRORONLY,

        [Parameter()]
        #Specifies the data files should be restored to the specified location using the operating system file names defined in the backup file.
        [string] ${MOVE-DATAFILES-TO},

        [Parameter()]
        #Specifies that filestreams should be restored to the specified location. The specified location must exist before the restore, otherwise the restore will fail. If the database contains multiple filestreams, each filestream will be restored to a separate subfolder.
        [string] ${MOVE-FILESTREAMS-TO},

        [Parameter()]
        #Only available with SQL Server 2005. Specifies that full text catalogs should be restored to the specified location. If the database contains multiple full text catalogs, each full text catalog will be restored to a separate subfolder.
        [string] ${MOVE-FULLTEXTCATALOGS-TO},

        [Parameter()]
        #Specifies the log files should be restored to a new location with the operating system file names specified in the backup file.
        [string] ${MOVE-LOGFILES-TO},

        [Parameter()]
        #Specifies that the backup files should be moved to another folder when the restore process completes. If the folder you specify does not exist, it will be created.
        [string] $MOVETO,

        [Parameter()]
        #Prevents a log file from being created for the restore process, even if errors or warnings are generated. You may want to use this option if you are concerned about generating a large number of log files, and are certain that you will not need to review the details of errors or warnings (for example, because it's possible to run the process again without needing to know why it failed).
        [switch] $NOLOG ,

        [Parameter()]
        #Specifies that once the restore has completed, the database should be checked for orphaned users. Database user names are considered to be orphaned if they do not have a corresponding login defined on the SQL Server instance.
        [switch] $ORPHAN_CHECK ,

        [Parameter()]
        #Specifies the password to be used with encrypted backup files.
        [securestring] $PASSWORD,

        [Parameter()]
        #Specifies the password file to be used with encrypted backup files.
        [securestring] $PASSWORDFILE,

        [Parameter()]
        #Specifies that the database should be restored, even if another database of that name already exists. The existing database will be deleted. REPLACE is required to prevent a database of a different name being overwritten by accident. REPLACE is not required to overwrite a database which matches the name recorded in the backup.
        [switch] $REPLACE ,

        [Parameter()]
        #Specifies that access to the restored database is to be limited to members of the db_owner, dbcreator or sysadmin roles. Return the database to multi-user or single-user mode using your SQL Server application.
        [switch] $RESTRICTED_USER ,

        [Parameter()]
        #Specifies that the results returned by the RESTORE command should be limited to just one result set. This may be useful if you want to manipulate results using a Transact-SQL script. Such scripts can only manipulate results when a single result set is returned. The RESTORE command will return two result sets by default in most cases, unless you specify the SINGLERESULTSET keyword.
        [switch] $SINGLERESULTSET ,

        [Parameter()]
        #Specifies a standby file that allows the recovery effects to be undone. The STANDBY option is allowed for offline restore (including partial restore). The option is disallowed for online restore.
        [string] $STANDBY,

        [Parameter()]
        #Specifies a point in time to which a transaction log backup should be restored. The database will be recovered up to the last transaction commit that occurred at or before the specified time.
        [string] $STOPAT,

        [Parameter()]
        #Specifies that incomplete transactions are to be rolled back. Recovery is completed and the database is in a usable state. Further differential backups and transaction log backups cannot be restored.
        [switch] $RECOVERY ,

        [Parameter()]
        #Specifies that incomplete transactions are not to be rolled back on restore. The database cannot be used but differential backups and transaction log backups can be restored.
        [switch] $NORECOVERY ,

        [Parameter()]
        #This will specify that the database should be in standby, and will automatically locate the correct standby location
        [switch] $READONLY ,

        [Parameter()]
        #This will specify that the files should be moved to a specific drive, and will automatically locate the correct drive locations.
        [switch] $DEFAULT_LOCATIONS ,

        [Parameter()]
        [ValidateRange(0, 6)]
        #Sets the SQL Backup Pro thread priority when the backup or restore process is run. Valid values are 0 to 6, and correspond to the following priorities:
        [int] $THREADPRIORITY
    )
    BEGIN { }
    PROCESS
    {
        try
        {
            <#
                This command is based off of parameters that are passed in, this is a black list of parameters that the redgate
                command won't need and shouldn't be included in the automatic variable list rollup.
            #>
            $configuration = @(
                'TargetSQLServerName'
                'SourceSQLServerName'
                'Type'
                'RestoreAs'
                'DatabaseName'
                'Disk'
                'Execute'
                'CommandLine'
                'Replication'
                'Encrypted'
                'Credential'
                'DecryptionCredential'
                'FileLocation'
                'DatabaseDataFileLogicalName'
                'StandbyLocation'
                'DatabaseLogFileLogicalName'
                'READONLY'
                'DEFAULT_LOCATIONS'
                'WhatIf'
            )

            $options = [ordered]@{}

            $defaultTargetLocations = Get-SQLServerDefaultFileLocation -SQLServerName $TargetSQLServerName

            if (($STANDBY -or $READONLY) -and -not($StandbyLocation))
            {
                <#
                    Okay, so figuring out where the UNDO files should go kind of sucks, I'm making some assumptions here about where to put these files.
                    I'm going to default to putting it into the "Backup" directory in the installation directory. Which I'm assuming is where you put master.
                    I'm open to suggestions on different ways to do this.
                #>
                $temp = Get-SQLServerDatabaseFile -SQLServerName $TargetSQLServerName -DatabaseName master | Where-Object DatabaseFileType -eq 'Data'
                $tempLocation = $temp.DatabaseFileLocation.TrimEnd("\DATA\$($temp.DatabaseFileName)")
                $StandbyLocation = "$tempLocation\Backup"

            }

            <#
                If $Disk is not passed, file location will allow you pass in a root directory.
                The assumption here is that you store your files in a location like this using the redgate AUTO naming.
                - $FileLocation\
                    - FULL
                    - DIFF
                    - LOG

                This will allow you to simply pass a root directory and based on your $Type variable, it will append on
                appropriate wildcard locations to make the restore work.
            #>
            if (!$Disk)
            {
                if ($Type -eq 'LATEST_ALL')
                {
                    $TypeDirectories = @('FULL', 'DIFF', 'LOG');
                }
                elseif ($Type -eq 'LATEST_FULL')
                {
                    $TypeDirectories = @('FULL');
                }
                elseif ($Type -eq 'LATEST_DIFF')
                {
                    $TypeDirectories = @('FULL', 'DIFF');
                }
                elseif ($Type -eq 'LOG')
                {
                    $TypeDirectories = @('LOG');
                }

                if ($Type -eq 'LOG')
                {
                    $Disks = "DISK = ''$fileLocation\LOG_$($DatabaseName)_*.sqb''";
                }
                else
                {
                    $Disks = -join ($TypeDirectories | ForEach-Object {"DISK = ''$fileLocation\$DatabaseName\$_\*.sqb'', "})
                    $Disks = $Disks.Trim().Substring(0, $Disks.Length - 2)
                    $Disks += " $Type"
                }
            }
            else
            {

                <#
                    To my knowledge, there is no way to tell the file is encrypted ahead of time. I include _ENCRYPTED at the
                    end of my files so that this command can tell if it needs to supply a password dynamically without having
                    to know ahead of time. The command used to just ignore a password if it didn't need one, but will now
                    error out and so you have to be sure not to supply one if it's not needed. For the people that don't use
                    my convention, you just need to pass the -Encrypted flag
                #>
                $Encrypted = ($Disk.Split('_')[-1] -eq 'ENCRYPTED.sqb' -or $Encrypted)

                if ($Encrypted -and -not($DecryptionCredential) -and -not($PASSWORD -or $PASSWORDFILE))
                {
                    $DecryptionCredential = (Get-Credential -UserName 'SQL Backup' -Message 'Enter password to decrypt backup file.')
                }

                if (-not($Encrypted))
                {
                    #if this is not encrypted, we want to add it to the configuration array. This will strip it out of the command
                    $configuration += 'PASSWORD'
                    $configuration += 'PASSWORDFILE'
                }

                $Disks = "DISK = ''$Disk''"
            }

            $backupType = '';
            switch ($Type)
            {
                'LATEST_FULL' { $backupType = 'DATABASE'}
                'LATEST_DIFF' { $backupType = 'DATABASE' }
                'LATEST_ALL' { $backupType = 'DATABASE' }
                'LOG' { $backupType = 'LOG'}
            }

            # This handles special situations for custom parameters.
            $PSBoundParameters.GetEnumerator()| ForEach-Object {
                # This is the default route. All other instructions will be handled differently
                if ($_.Key -notin $configuration)
                {
                    $options.Add($_.Key, $_.Value)
                }

                if ($_.Key -eq 'READONLY')
                {
                    $options.Add('STANDBY', "$($StandbyLocation)\UNDO_$DatabaseName.dat")
                }

                if ($_.Key -eq 'DEFAULT_LOCATIONS' -and -not($RestoreAs))
                {
                    $options.Add('MOVE-DATAFILES-TO', $defaultTargetLocations.DefaultData)
                    $options.Add('MOVE-LOGFILES-TO', $defaultTargetLocations.DefaultLog)
                }

                # this is kind of involved, but super useful. It lets you rename the database when you restore it and figures out a lot of stuff for you.
                if ($_.Key -eq 'RestoreAs' -and -not([string]::IsNullOrEmpty($_.Value)))
                {
                    $databaseFiles = Get-SQLServerDatabaseFiles -SQLServerName $SourceSQLServerName -DatabaseName $DatabaseName
                    if (-not($databaseFiles))
                    {
                        Write-Verbose "Couldn't find file info for $DatabaseName on $SourceSQLServerName. Trying to locate the info on the target $TargetSQLServerName"
                        $databaseFiles = Get-SQLServerDatabaseFiles -SQLServerName $TargetSQLServerName -DatabaseName $DatabaseName
                    }

                    Write-Verbose "Finding the logical and physical file(s) names for the data so that we can rename the database."
                    $dataFiles = $databaseFiles | Where-Object DatabaseFileType -eq 'Data'
                    if ($dataFiles)
                    {
                        Write-Verbose 'Found the files on the source server. Using that to rename and move the database.'
                        foreach ($file in $DataFiles)
                        {
                            $options.Add("MOVE-''$($file.DatabaseLogicalName)''-TO", "$($defaultTargetLocations.DefaultData)\$($file.DatabaseFileName -replace $DatabaseName, $RestoreAs)")
                        }
                    }
                    elseif ($DatabaseDataFileLogicalName)
                    {
                        Write-Verbose "Couldn't find the database on the source server. Using the name provided to move the Logical files."
                        $options.Add("MOVE-''$DatabaseDataFileLogicalName''-TO", "$($defaultTargetLocations.DefaultData)\$($file.DatabaseFileName -replace $DatabaseName, $RestoreAs)")
                    }
                    else
                    {
                        Write-Verbose "Couldn't find the database on the source server. I'm going to have to guess what the database files was named. PROTIP: this might not work."
                        $options.Add("MOVE-''$DatabaseName''-TO", "$($defaultTargetLocations.DefaultData)\$RestoreAs.mdf")
                    }

                    Write-Verbose "Finding the logical and physical file(s) names for the log so that we can rename the database."
                    $logFiles = $databaseFiles | Where-Object DatabaseFileType -eq 'Log'
                    if ($logFiles)
                    {
                        Write-Verbose 'Found the files on the source server. Using that to rename and move the database.'
                        # You really shouldn't have multiples here. I"m about to put them back on the same drive. - https://www.brentozar.com/blitz/multiple-log-files-same-drive/
                        foreach ($file in $logFiles)
                        {
                            $options.Add("MOVE-''$($file.DatabaseLogicalName)''-TO", "$($defaultTargetLocations.DefaultData)\$($file.DatabaseFileName -replace $DatabaseName, $RestoreAs)")
                        }
                    }
                    elseif ($DatabaseLogFileLogicalName)
                    {
                        Write-Verbose "Couldn't find the database on the source server. Using the name provided to move the Logical files."
                        $options.Add("MOVE-''$DatabaseLogFileLogicalName''-TO", "$($defaultTargetLocations.DefaultData)\$($file.DatabaseFileName -replace $DatabaseName, $RestoreAs)")
                    }
                    else
                    {
                        Write-Verbose "Couldn't find the database on the source server. I'm going to have to guess what the database files was named. PROTIP: this might not work."
                        $options.Add("MOVE-''$DatabaseName''-TO", "$($defaultTargetLocations.DefaultData)\$RestoreAs.ldf")
                    }
                }
            }

            if ($DecryptionCredential -and -not($options.Contains('PASSWORD')))
            {
                $options.Add('PASSWORD', $DecryptionCredential.Password)
            }

            $with = 'WITH '

            #Build the with string so that it can be added to the command
            foreach ($option in $options.GetEnumerator())
            {
                $paramType = $option.Value.GetType().Name
                $paramName = $option.Key.ToString().ToLower()
                $paramValue = $option.Value.ToString()

                if ($paramValue)
                {
                    if (($paramType -eq 'SwitchParameter'))
                    {
                        $with += "$paramName, "
                    }
                    elseif ($paramName -eq 'password')
                    {
                        $unsecureString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($option.Value)
                        $with += "PASSWORD = ''$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($unsecureString))'', "
                    }
                    elseif ($paramName -eq 'passwordfile')
                    {
                        $unsecureString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($option.Value)
                        $with += "PASSWORD = ''FILE:$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($unsecureString))'', "
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
            else
            {
                $with = ''
            }

            $restoreCommand = "EXEC master..sqlbackup '-SQL ""RESTORE $backupType [$(@{$true=$DatabaseName;$false=$RestoreAs}[-not ($RestoreAs)])] FROM $Disks $with""'"


            if ($PSCmdlet.ShouldProcess($TargetSQLServerName, $restoreCommand))
            {
                $command = "
                        DECLARE @errorcode INT
                              , @sqlerrorcode INT
                        $($restoreCommand), @errorcode OUTPUT, @sqlerrorcode OUTPUT;
                        IF (@errorcode >= 500) OR (@sqlerrorcode <> 0)
                        BEGIN
                            RAISERROR ('SQL Backup failed with exit code: %d;  SQL error code: %d', 16, 1, @errorcode, @sqlerrorcode);
                        END"

                $params = @{
                    ServerInstance = $TargetSQLServerName
                    Database = 'master'
                    Query = $command
                    Credential = $Credential
                    QueryTimeout = 7200
                    As = 'SingleValue'
                }

                #This will output the command in a formatted way
                Write-Verbose ("`n`nRestoring database $DatabaseName to $TargetSQLServerName`n")
                Write-Verbose ($command.Replace(',', "`n,") | Out-String)

                try
                {
                    $result = Invoke-Sqlcmd2 @params -ErrorAction Stop
                }
                catch
                {
                    # exception message comes through like this: Exception calling "Fill" with "1" argument(s): "SQL Backup failed with exit code: 850;  SQL error code: 0"
                    # we want to get the SQL Backup exit code, and the SQL error code.
                    $message = $_.Exception.Message.TrimEnd('"')
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
            throw $_.Exception
            break
        }
    }
}