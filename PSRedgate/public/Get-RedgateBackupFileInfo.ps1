function Get-RedgateBackupFileInfo
{
    <#
    .SYNOPSIS
    This cmdlet will return information stored in the backup file.

    .DESCRIPTION
    This is useful for determining things like what server the database backup originated from, when it was taken, how large it was, ect.

    .EXAMPLE
    Get-RedgateBackupInfo -SQLServerName SQLEXAMPLE1 -BackupFile 'C:\Backups\my_db.sqb'

    This will return the basic info stored in the backup file. The SQL Server name is required because this cmdlet uses the master..sqlbackup stored procedure. It has nothing to do with the source db.

    .EXAMPLE
    Get-RedgateBackupInfo -SQLServerName SQLEXAMPLE1 -BackupFile 'C:\Backups\my_db_encrypted.sqb'

    Will attempt to decrypt the backup file using and return the standard information. This will parse the name and if it finds _encrypted it will try to decrypt it. If you did not provide a credential object, a password will be requested.

    .EXAMPLE
    Get-RedgateBackupInfo -SQLServerName SQLEXAMPLE1 -BackupFile 'C:\Backups\my_db.sqb' -Encrypted

    Will attempt to decrypt the backup file using and return the standard information. If you did not provide a credential object, a password will be requested.

    .EXAMPLE
    Get-RedgateBackupInfo -SQLServerName SQLEXAMPLE1 -BackupFile 'C:\Backups\my_db.sqb' -Credential $credential

    Will return the information that was stored in the file. This will use the credentials passed in to execute the query on the SQL Server.

    .NOTES
    General notes
    #>
    [CmdletBinding()]
    param(
        [parameter()]
        # This is the name of the SQL Server where SQL Backup is installed. This cmdlet needs to run the master..sqlbackup stored procedure so provide a server where it is installed.
        [string] $SQLServerName,

        [parameter(ValueFromPipeline)]
        # The full path to the files that you would like to examine and receive information on.
        [string] $BackupFile,

        [parameter()]
        # If the backup is encrypted, pass a credential object with the password needed to decrypt the file.
        [System.Management.Automation.PSCredential] $DecryptionCredential,

        [parameter()]
        # If you would like to execute this as a different user and not use integrated auth, pass in a credential object to run as a different user.
        [System.Management.Automation.PSCredential] $Credential,

        [parameter()]
        # This flag indicates that the file is encrypted and we should pass the password to the cmdlet. This requires all files passed in the pipeline to be encrypted.
        [switch] $Encrypted
    )
    BEGIN {}
    PROCESS
    {

        $with = 'WITH '

        $Encrypted = ($BackupFile.Split('_')[-1] -eq 'ENCRYPTED.sqb' -or $Encrypted)

        if ($Encrypted -and -not($DecryptionCredential))
        {
            $DecryptionCredential = (Get-Credential -UserName 'SQL Backup' -Message 'Enter password to decrypt backup file.')
        }

        if ($Encrypted)
        {
            $with += "PASSWORD = ''$($DecryptionCredential.GetNetworkCredential().Password)'',"
        }

        $with += ' SINGLERESULTSET'

        $query = "EXEC master..sqlbackup '-sql ""RESTORE SQBHEADERONLY FROM DISK = [$BackupFile] $with""'"

        Write-Debug $query
        $result = Invoke-Sqlcmd2 -ServerInstance $SQLServerName -Database 'master' -Query $query -As SingleValue -Credential $Credential

        $fileInfo = @{}

        foreach ($prop in $result.Split("`n"))
        {
            $prop = $prop.split(':', 2)
            if ($prop.Count -gt 1)
            {
                [string]$key = $prop[0]
                [string]$value = $prop[1]

                if ($key -ne '' -and $value -ne '')
                {
                    $key = (Get-Culture).TextInfo.ToTitleCase($key).Replace(' ', '').Trim()
                    if ($key -in @('BackupStart', 'BackupEnd'))
                    {
                        $value = [DateTime]::Parse($value.Trim())
                    }
                    elseif ($key -eq 'BackupType')
                    {
                        switch ($value.Trim())
                        {
                            '1 (Database)' {  $value = 'FULL' }
                            '2 (Transaction log)' {  $value = 'LOG' }
                            '5 (Differential database)' {  $value = 'DIFF' }
                        }
                    }
                    else
                    {
                        $value = $value.Trim()
                    }
                    $fileInfo.Add($key, $value)
                }
            }
        }
        if ($fileInfo.SqlBackupExitCode)
        {
            Write-Warning "SQL Backup Error: `n`n$(Get-RedgateSQLBackupError -ErrorNumber $fileInfo.SqlBackupExitCode )"
        }
        else
        {
            Write-Output $fileInfo
        }
    }
    END { }
}