function Get-SQLServerDefaultFileLocation
{
    <#
    .SYNOPSIS
        This will return the default location of the files used by sql server such as data, log, and backup.
    .DESCRIPTION
        This cmdlet is useful for figuring out where a sql server is installed and where it is keeping it's data.
    .EXAMPLE
        Get-SQLServerDefaultFileLocation -SQLServerName SQLEXAMPLE1

        Will return a hash table that will look like this:

        {
            DefaultData = 'D:\EXAMPLE1'
            DefaultLog  = 'L:\EXAMPLE1'
            DefaultBackup = 'C:\Program Files\Microsoft SQL Server\MSSQL11\MSSQL\Backup'
        }

#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [Alias('ServerInstance')]
        # The server you want to create a remote connection to
        [string] $SQLServerName,

        [parameter()]
        # If you would like to execute this as a different user and not use integrated auth, pass in a credential object to run as a different user.
        [System.Management.Automation.PSCredential] $Credential
    )
    BEGIN {}
    PROCESS
    {
        try
        {
            $query = "DECLARE @DefaultData NVARCHAR(512)
                        , @DefaultLog NVARCHAR(512)
                        , @DefaultBackup NVARCHAR(512)
                        , @MasterData NVARCHAR(512)
                        , @MasterLog NVARCHAR(512);

                        EXEC master.sys.xp_instance_regread N'HKEY_LOCAL_MACHINE'
                                                        , N'Software\Microsoft\MSSQLServer\MSSQLServer'
                                                        , N'DefaultData'
                                                        , @DefaultData OUTPUT;

                        EXEC master.sys.xp_instance_regread N'HKEY_LOCAL_MACHINE'
                                                        , N'Software\Microsoft\MSSQLServer\MSSQLServer'
                                                        , N'DefaultLog'
                                                        , @DefaultLog OUTPUT;

                        EXEC master.sys.xp_instance_regread N'HKEY_LOCAL_MACHINE'
                                                        , N'Software\Microsoft\MSSQLServer\MSSQLServer'
                                                        , N'BackupDirectory'
                                                        , @DefaultBackup OUTPUT;

                        EXEC master.sys.xp_instance_regread N'HKEY_LOCAL_MACHINE'
                                                        , N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters'
                                                        , N'SqlArg0'
                                                        , @MasterData OUTPUT;

                        SELECT  @MasterData = SUBSTRING( @MasterData, 3, 255 );
                        SELECT  @MasterData = SUBSTRING( @MasterData, 1, LEN( @MasterData ) - CHARINDEX( '\', REVERSE( @MasterData )));

                        EXEC master.sys.xp_instance_regread N'HKEY_LOCAL_MACHINE'
                                                        , N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters'
                                                        , N'SqlArg2'
                                                        , @MasterLog OUTPUT;

                        SELECT  @MasterLog = SUBSTRING( @MasterLog, 3, 255 );
                        SELECT  @MasterLog = SUBSTRING( @MasterLog, 1, LEN( @MasterLog ) - CHARINDEX( '\', REVERSE( @MasterLog )));

                        SELECT  ISNULL( @DefaultData, @MasterData ) AS DefaultData
                              , ISNULL( @DefaultLog, @MasterLog ) AS DefaultLog
                              , ISNULL( @DefaultBackup, @MasterLog ) AS DefaultBackup;"

            Write-Debug $query
            $result = Invoke-Sqlcmd2 -ServerInstance $SQLServerName -Database 'master' -Query $query -Credential $Credential
            Write-Output $result

        }
        catch
        {
            Write-Output $_.Exception | Format-List -Force
            break
        }
    }
    END {}
}