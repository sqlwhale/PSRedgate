function Get-SQLServerDatabaseFile
{
    <#
    .SYNOPSIS
        This cmdlet will return a collection outlining all of the files on disk used by a database.

    .DESCRIPTION
        If we need a hash with the name of the database and the location of the files that are being used by the database. The output looks like this:
        [
            DatabaseName          : ExampleDB
            FileType              : LOG
            DatabaseFileType      : Logs
            DatabaseFileLocation  : L:\EX1\ExampleDB_log.ldf
            DatabaseFileName      : ExampleDB_log.ldf
            DatabaseFileNameNoExt : ExampleDB_log
            FileOrdinal           : 1

            DatabaseName          : ExampleDB
            FileType              : ROWS
            DatabaseFileType      : Data
            DatabaseFileLocation  : M:\EX1\ExampleDB.mdf
            DatabaseFileName      : ExampleDB.mdf
            DatabaseFileNameNoExt : ExampleDB
            FileOrdinal           : 1
        ]
        There might be more than one file for either of these. The file ordinal will tell you the file index.

    .EXAMPLE
        Get-SQLServerDatabaseFiles -SQLServerName SQLEXAMPLE1 -DatabaseName ExampleDB

        Return the files for the database specified on the sql server provided.

    .EXAMPLE
        Get-SQLServerDatabaseFiles -SQLServerName SQLEXAMPLE1

        Return the files used by all databases in use on the sql server provided.

#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [Alias('ServerInstance')]
        # Name of the sql server you want to connect to and examine the files of.
        [string] $SQLServerName,

        [parameter()]
        [Alias('Database')]
        # Name of the database you would like to retrieve the files for
        [string] $DatabaseName,

        [parameter()]
        # If you would like to execute this as a different user and not use integrated auth, pass in a credential object to run as a different user.
        [System.Management.Automation.PSCredential] $Credential
    )
    BEGIN { }
    PROCESS
    {
        try
        {
            # this is some database hackery that I wrote to help me find the files. There is probably an SMO way that you could get this info, but I'm a DBA. :)
            $query = "WITH database_file_names AS (
                            SELECT  db.name AS DatabaseName
                                , mf.type_desc AS FileType
                                , mf.name AS LogicalName
                                , mf.physical_name AS DBFileLocation
                                , REVERSE( LEFT(REVERSE( mf.physical_name ), PATINDEX( '%\%', REVERSE( mf.physical_name )) - 1)) AS DBFileName
                            FROM    sys.master_files mf
                                    INNER JOIN sys.databases db
                                        ON db.database_id = mf.database_id
                        )
                        SELECT    dbfn.DatabaseName
                                , dbfn.FileType
                                , IIF(dbfn.FileType = 'ROWS', 'Data', 'Log') AS DatabaseFileType
                                , dbfn.DBFileLocation AS DatabaseFileLocation
                                , dbfn.LogicalName AS DatabaseLogicalName
                                , dbfn.DBFileName AS DatabaseFileName
                                , REPLACE( REPLACE( REPLACE( dbfn.DBFileName, '.mdf', '' ), '.ldf', '' ), '.ndf', '' ) AS DatabaseFileNameNoExt
                                , ROW_NUMBER() OVER ( PARTITION BY dbfn.DatabaseName
                                                                , dbfn.FileType
                                                        ORDER BY dbfn.DBFileLocation
                                ) AS FileOrdinal
                        FROM    database_file_names dbfn
                        WHERE (
                                1 = 1
                                $(if($DatabaseName){
                                    "AND dbfn.DatabaseName = '$DatabaseName'"
                                })
                            )"

            Write-Debug $query
            $result = Invoke-Sqlcmd2 -ServerInstance $SQLServerName -Database 'master' -Query $query -Credential $Credential
            Write-Output $result
        }
        catch
        {
            Write-Output $_.Exception | Format-List -Force
            break;
        }
    }
    END { }
}