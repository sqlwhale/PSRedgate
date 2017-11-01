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

    [CmdletBinding()]
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
        # The location that you want this file backed up.
        [string] $Disk,

        [parameter()]
        # If you want to encrypt this backup, provide a credential object containing a password to encrypt.
        [System.Management.Automation.PSCredential] $EncryptionCredential,

        [parameter()]
        # If you would like to execute this as a different user and not use integrated auth, pass in a credential object to run as a different user.
        [System.Management.Automation.PSCredential] $Credential,

        [parameter()]
        # This flag indicates that the file is encrypted and we should pass the password to the cmdlet. This requires all files passed in the pipeline to be encrypted.
        [switch] $Encrypted,

        [Parameter(Mandatory = $false, Position = 5)]
        # If this command should execute the backup, or output the command.
        [switch] $Execute,

        [Parameter()]
        #Specifies the password to be used with encrypted backup files.
        [SecureString] $PASSWORD,

        [Parameter()]
        #Specifies the password file to be used with encrypted backup files.
        [SecureString] $PASSWORDFILE,

        [Parameter(Mandatory = $false)]
        # The description of the backup file
        [string] $DESCRIPTION,

        [Parameter(Mandatory = $false)]
        # The location that you want this file backup copied to. Can be multiples separated by commas.
        $COPYTO,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 8)]
        # Specifies the compression level. The default value is 1.
        [int] $COMPRESSION = 1,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 120)]
        # The time interval between retries, in seconds, following a failed data-transfer operation.
        [int] $DISKRETRYINTERVAL = 30,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 20)]
        # The maximum number of times to retry a failed data-transfer operation.
        [int] $DISKRETRYCOUNT = 10,

        [Parameter(Mandatory = $false)]
        [ValidateRange(2, 32)]
        # Specifies the number of threads to be used to create the backup, where n is an integer between 2 and 32 inclusive.
        [int] $THREADCOUNT = 2,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 6)]
        # The maximum number of times to retry a failed data-transfer operation.
        [int] $THREADPRIORITY = 3,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 360)]
        # The number of days to retain the backup files before beginning to erase them
        [int] $ERASEFILES,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 360)]
        # The number of days to retain the backup files before beginning to erase them
        [int] $ERASEFILES_PRIMARY,

        [Parameter(Mandatory = $false)]
        # Specifies a copy-only backup.
        [switch] $COPY_ONLY,

        [Parameter(Mandatory = $false)]
        # Specifies that files with the same name in the primary backup folder should be overwritten.
        [switch] $INIT,

        [Parameter(Mandatory = $false)]
        #Specifies whether a backup checksum should be created.
        [switch] $CHECKSUM,

        [Parameter(Mandatory = $false)]
        #This option specifies that a full backup should be created if required to take a differential or transaction log backup.
        [switch] $FULLIFREQUIRED,

        [Parameter(Mandatory = $false)]
        #Specifies that a log file should only be created if SQL Backup Pro encounters an error during the backup process, or the backup completes successfully but with warnings.
        [switch] $LOG_ONERROR,

        [Parameter(Mandatory = $false)]
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

            if ($EncryptionCredential -and -not($options.Contains('PASSWORD')))
            {
                $options.Add('PASSWORD', $EncryptionCredential.Password)
            }

            if (-not($Encrypted))
            {
                #if this is not encrypted, we want to add it to the configuration array. This will strip it out of the command
                $configuration += 'PASSWORD'
                $configuration += 'PASSWORDFILE'
            }

            $options = $PSBoundParameters.GetEnumerator() | Where-Object {$_.Key -notin $configuration}



            if (-not($options.Contains('Disk')))
            {
                $options.Add('Disk', $(Get-SQLServerDefaultFileLocation -SQLServerName $SQLServerName).DefaultBackup)
            }

            $arguments = Get-RedgateSQLBackupParameter -Parameters $options

            $backupType = $null
            switch ($Type)
            {
                'FULL' { $backupType = 'DATABASE'}
                'DIFF' { $backupType = 'DATABASE'; $with += 'DIFFERENTIAL, ' }
                'LOG' { $backupType = 'LOG'}
            }

            if ($Encrypted -and -not($EncryptionCredential) -and -not($PASSWORD -or $PASSWORDFILE))
            {
                $EncryptionCredential = (Get-Credential -UserName 'SQL Backup' -Message 'Enter password to encrypt backup file.')
            }


            $Disks = "DISK = ''$Disk''"


            #if a disk value is not passed, it will look up the backup replication spot designated by get-serverlist
            if (!$Disk)
            {
                #add a different marker if the file is encrypted
                if ($PASSWORD -or $PASSWORDFILE)
                {
                    $marker = '_ENCRYPTED'
                }

                $Disk = "''$( @{ $true = $serverListEntry.BackupLocation; $false = $serverListEntry.BackupLocation }[!$Replication] )\<database>\<type>\<TYPE>_<DATABASE>_<DATETIME yyyy_mm_dd_hh_nn_ss>$marker.sqb''"
            }

            if ($CommandLine)
            {
                $command = ''
            }
            else
            {
                $backupCommand = "EXEC master..sqlbackup '-SQL ""BACKUP $backupType [$DatabaseName] TO DISK = $Disk $with""'"
                $command = "
                    DECLARE @errorcode INT
                    DECLARE @sqlerrorcode INT
                    $($backupCommand), @errorcode OUTPUT, @sqlerrorcode OUTPUT;
                    IF (@errorcode >= 500) OR (@sqlerrorcode <> 0)
                    BEGIN
                    RAISERROR ('SQL Backup failed with exit code: %d  SQL error code: %d', 16, 1, @errorcode, @sqlerrorcode)
                END"
            }

            if ($Execute)
            {
                $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
                $dataSet = New-Object System.Data.DataSet
                $sqlConnectString = "Data Source=$SQLServerName; Initial Catalog=master; Integrated Security=True"
                $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($sqlConnectString)

                $sqlConnection.Open()

                #This will output the command in a formatted way
                Write-Verbose "`n`nBacking up database $DatabaseName from $SQLServerName`n"
                Write-Verbose $command.Replace(',', "`n,")

                $SQLCommand = New-Object system.Data.SqlClient.SqlCommand ($command, $sqlConnection)
                $SQLCommand.CommandTimeout = 7200
                $sqlAdapter.SelectCommand = $SQLCommand
                $sqlAdapter.Fill($dataSet) | Out-Null
                $sqlConnection.Close()
                Write-Verbose $dataSet.Tables[0]
            }
            else
            {
                Write-Output $backupCommand
            }
        }
        catch
        {
            Write-Output  -Object $_.Exception | Format-List -Force
            break;
        }
    }
    END {}
}