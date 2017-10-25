function Invoke-RedgateSQLCompare
{
    <#
    .SYNOPSIS
        This is a powershell wrapper for interacting with the command line tools for SQL Compare. This will assist with making use of the underlying features of SQL Compare
        from inside your powershell scripts and cmdlets.

    .DESCRIPTION
        This cmdlet has a one-to-one parameter set that matches to the parameters passed to the SQLCompare.exe utility. The point of this cmdlet is to make it easier to
        use sql compare from powershell by promoting all of the parameters to first class citizens the way that powershell allows. The documentation for these parameters
        comes directly from Redgate's website and is fantastic. I highly recommend reading their descriptions and built in examples.

    .EXAMPLE
        Invoke-RedgateSQLCompare -Server1 SQLEXAMPLE1 -Database1 EXAMPLEDB -MakeSnapshot 'C:\temp\exampledb_snapshot.snp'

        This will create a schema snapshot of the database EXAMPLEDB on server SQLEXAMPLE1 and will save the snp file to the location specified.

    .EXAMPLE
        Invoke-RedgateSQLCompare -Snapshot1 'C:\temp\exampledb_snapshot.snp' -Server2 SQLEXAMPLE1 -Database2 EXAMPLEDB2 -Synchronize

        This will apply the schema snapshot taken from a database and synchronize the schema to EXAMPLEDB2 on server SQLEXAMPLE1

    .NOTES
        This is still sort of raw, I'd like to sit down and map out all of the related parameters and create parameter sets out of them.
        I would also like to create a lot of examples of things you an do with this cmdlet.
        I'm standing on the shoulders of giants with this stuff, the sql compare engine is a really amazing piece of software engineering and in my experience is pretty rock solid.
        This cmdlet is just to make it easier to interact with it from powershell.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [parameter()]
        [Alias('aow')]
        [ValidateSet('None' , 'Medium' , 'High')]
        # Specifies that SQL Compare won't run a deployment if there are any serious deployment warnings. If you don't specify this switch, SQL Compare will ignore warnings and run the deployment.
        [string]$AbortOnWarnings = 'None',

        [parameter()]
        #Attempts to activate SQL Compare.
        [switch]$activateSerial,

        [parameter()]
        # Runs a file containing an XML argument specification:
        [string]$Argfile,

        [parameter()]
        # When /assertidentical is specified, SQL Compare will return an exit code of 0 if the objects being compared are identical. If they aren't identical, it will return exit code 79.
        [string]$Assertidentical,

        [parameter()]
        [Alias('b1')]
        <#
        Specifies the backup to be used as the source.
        You must add all of the files making up the backup set you want to compare:
            sqlcompare /Backup1:D:\BACKUPS\WidgetStaging.bak /db2:WidgetStaging
        To specify more than one backup file, the file names are separated using semicolons:
            sqlcompare /Backup1:D:\BACKUPS\WidgetDev_Full.bak; D:\BACKUPS\WidgetDev_Diff.bak /db2:WidgetDev
        #>
        [string]$Backup1,

        [parameter()]
        [Alias('b2')]
        <#
        Specifies the backup to be used as the target.
        You must add all of the files making up the backup set you want to compare:
            sqlcompare /db1:WidgetStaging /Backup2:D:\BACKUPS\WidgetStaging.bak
        #>
        [string]$Backup2,

        [parameter()]
        [Alias('bc')]
        [ValidateRange(1, 3)]
        <#
        Compresses a backup using one of three compression levels.
        Arguments:
        1  Compression level 1 is the fastest compression, but results in larger backup files. On average, the backup process is 10% to 20% faster than when compression level 2 is used, and 20% to 33% fewer CPU cycles are used. Backup files are usually 5% to 9% larger than those produced by compression level 2. However, if a database contains frequently repeated values, compression level 1 can produce backup files that are smaller than if you used compression level 2 or 3. For example, this may occur for a database that contains the results of Microsoft SQL Profiler trace sessions.
        2  This compression level uses the zlib compression algorithm, and is a variation of compression level 3. On average, the backup process is 15% to 25% faster than when compression level 3 is used, and 12% to 14% fewer CPU cycles are used. Backup files are usually 4% to 6% larger.
        3  Compression level 3 uses the zlib compression algorithm. This compression level generates the smallest backup files in most cases, but it uses the most CPU cycles and takes the longest to complete.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backupcompression:3
        #>
        [int]$BackupCompression,

        [parameter()]
        [Alias('be')]
        <#
        Encrypts a backup using 128-bit encryption.
        You can only encrypt Redgate (SQL Backup Pro) backups.
        If you encrypt a backup, you must specify a password using /BackupPassword.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backupencryption /backuppassword:P@ssw0rd
        #>
        [switch]$BackupEncryption,

        [parameter()]
        [Alias('bf')]
        <#
        The file name to use when creating a backup.
        For Redgate backups, use the file extension .sqb. For native SQL Server backups, use .bak.
        sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backupfile:WidgetProductionBackup.sqb
        #>
        [string]$BackupFile,

        [parameter()]
        [Alias('bd')]
        <#
        The folder to use for storing backups.
        If you don't use this switch, backups are stored in the folder specified in the SQL Backup options for the SQL Server instance.
        If you're not using SQL Backup, or no backup file locations have been set up, backups are stored in the SQL Server instance's default backup folder,
        for example: C:\Program Files\Microsoft SQL Server\MSSQL11.SQL2012\MSSQL\Backup
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backupfolder:C:\Backups
        #>
        [string]$BackupFolder,

        [parameter()]
        [Alias('bth')]
        [ValidateRange(1, 32)]
        <#
        Uses multiple threads to speed up the backup process. SQL Backup can use up to a maximum of 32 threads.
        We recommend you start with one thread fewer than the number of processors. For example, if you are using four processors, start with three threads.
        You can only use multiple threads with Redgate (SQL Backup Pro) backups.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backupnumberofthreads:2
        #>
        [int]$BackupNumberOfThreads,

        [parameter()]
        [Alias('boe')]
        # Overwrites existing backup files of the same name when creating a backup.
        [switch]$BackupOverwriteExisting,

        [parameter()]
        [Alias('bt')]
        [ValidateSet('Full' , 'Differential' )]
        <#
        The type of backup to perform.
        Arguments:
            Full - 	Full backup
            Differential -	Differential backup
        The default is Full.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backuptype:differential
        #>
        [string]$BackupType = 'Full',

        [parameter()]
        [Alias('bp')]
        # The password to use when encrypting a backup. sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backupencryption /backuppassword:P@ssw0rd
        [securestring]$BackupPassword,

        [parameter()]
        [Alias('bpsw1')]
        # Specifies the password for the source backup. sqlcompare /Backup1:D:\BACKUPS\WidgetStaging.bak /BackupPasswords1:P@ssw0rd /db2:WidgetProduction
        [SecureString]$BackupPasswords1,

        [parameter()]
        [Alias('bpsw2')]
        # Specifies the password for the target backup. sqlcompare /db1:WidgetStaging /Backup2:D:\BACKUPS\WidgetProduction.bak /BackupPassword2:P@ssw0rd
        [SecureString]$BackupPasswords2,

        [parameter()]
        [Alias('bpr')]
        [ValidateSet('Native' , 'SQB' )]
        <#
        The format of the backup file to create when backing up the target database.
        Arguments:
            Native - Native SQL Server backup (.bak)
            SQB - SQL Backup Pro backup (.sqb)
        The default is native in SQL Compare 11.1.5 and later. On previous versions, the default was SQB.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup /backupprovider:native
        #>
        [string]$BackupProvider = 'Native',

        [parameter()]
        [Alias('bks1')]
        <#
        If you are comparing a backup set that contains multiple files, use the /BackupSet1 switch to specify the files which make up the source backup set,
        and use the /BackupSet2 switches to specify the files which make up the target:
            sqlcompare /Backup1:"D:\MSSQL\BACKUP\WidgetDev.bak" /BackupSet1:"2008-09-23 Full Backup" /db2:WidgetLive
        If the backup set switches aren't specified, SQL Compare uses the latest backup set.
        To specify more than one backup file, the file names are separated using semi-colons:
            sqlcompare /Backup1:D:\BACKUPS\WidgetDev_Full.bak; "D:\BACKUPS\WidgetDev_Diff.bak" /db2:WidgetDevlopment
        For encrypted backups that have been created using SQL Backup, use the /BackupPasswords1 and /BackupPasswords2 switches to specify the passwords; when there is more than one password, the passwords are separated using semi-colons.
        #>
        [string]$BackupSet1,

        [parameter()]
        [Alias('bks2')]
        <#
        Specifies which backup set to use for the target backup:
            sqlcompare /db1:WidgetProduction /BackupSet2:"2008-09-23 Full Backup"
        #>
        [string]$BackupSet2,

        [parameter()]
        [Alias('db1')]
        <#
        Specifies a database to use as the source:
            sqlcompare /Database1:WidgetStaging /Database2:WidgetProduction
        #>
        [string]$Database1,

        [parameter()]
        [Alias('db2')]
        # Specifies a database to use as the target.
        [string]$Database2,

        [parameter()]
        # This switch is case sensitive. Attempts to deactivate the application. An internet connection is required to deactivate the product.
        [switch]$deactivateSerial,

        [parameter()]
        <#
        Use this as the target data source to make a script that creates the source database schema. You can use this script with SQL Packager 8.
        For example, you want to package the schema of a database, WidgetStaging, so that when the package is run it will create a copy of the database schema.
            sqlcompare /Server1:MyServer\SQL2014 /Database1:WidgetStaging /empty2 /ScriptFile:"C:\Scripts\WidgetStagingSchema.sql"
        #>
        [switch]$empty2,

        [parameter()]
        [ValidateSet('Additional ', 'Assembly', 'AsymmetricKey', 'Certificate', 'Contract', 'DdlTrigger', 'Different ', 'EventNotification', 'ExtendedProperty', 'FullTextCatalog', 'FullTextStoplist', 'Function', 'Identical ', 'MessageType', 'Missing ', 'PartitionFunction', 'PartitionScheme', 'Queue', 'Role', 'Route', 'Rule', 'Schema', 'SearchPropertyList', 'Sequence', 'Service', 'ServiceBinding', 'Static data ', 'StoredProcedure', 'SymmetricKey', 'Synonym', 'Table', 'User', 'UserDefinedType', 'View', 'XmlSchemaCollection')]
        <#
        Excludes objects from the comparison. For example, to exclude objects that are identical in both the source and target:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /exclude:Identical
        To exclude an object type:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /exclude:table
        To exclude specific objects, use a regular expression:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /exclude:table:Widget*
        For more examples using regular expressions, see Selecting tables with unrelated names.
        If you want to set up complex rules to exclude objects (eg to exclude tables with a specific name and owner), use a filter instead.
        To exclude more than one object or object type, use multiple /exclude switches:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /exclude:table:WidgetReferences /exclude:view
        If an object is matched by both /include and /exclude, the /exclude rule takes priority and the object is excluded.
        You can't use /exclude with the /project switch.
            Additional - Objects that aren't in the source (eg /db1).
            Missing - Objects that aren't in the target (eg /db2).
            Different - Objects that are the source and the target, but are different.
            Identical - Objects that are identical in the source and the target.
            Static data - Static data in a source-controlled database or a scripts folder.
        To exclude object types, use:
            Assembly AsymmetricKey Certificate Contract DdlTrigger
            EventNotification ExtendedProperty FullTextCatalog FullTextStoplist
            Function MessageType PartitionFunction PartitionScheme Queue
            Role Route Rule Schema SearchPropertyList Sequence
            Service ServiceBinding StoredProcedure SymmetricKey Synonym
            Table User UserDefinedType View XmlSchemaCollection
        #>
        [string]$exclude,

        [parameter()]
        [Alias('ftr')]
        <#
        Specifies a custom filter to select objects for deployment.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /filter:MarketingViewsOnly.scpf
        You can set up a filter to include or exclude objects based on their type, name, and owner (schema) name.
        This is useful, for example, if you want to create complex selection rules without using regular expressions.
            Filters are set up in the user interface.
            Filters are saved with the extension .scpf
            filter can't be used with /Include or /Exclude.

            If you use /filter with /project, the filter you specify overrides any filter used in the project.
            For more information, see Using filters.
        #>
        [string]$Filter
        ,

        [parameter()]
        [Alias('f')]
        # Forces the overwriting of any output files that already exist. If this switch isn't used and a file of the same name already exists, the program will exit with the exit code indicating an IO error.
        [switch]$Force,

        [parameter()]
        [Alias('/?')]
        <#
        Displays the list of switches in the command line with basic descriptions.
        If /help is used with any switches except /verbose, /html, /out, /force or /outputwidth then those extra switches will be ignored;
        the help message will be printed and the process will end with exit code 0.
        #>
        [switch]$Help,

        [parameter()]
        # Outputs the help text as HTML. Must be used with the /help switch.
        [switch]$HTML,

        [parameter()]
        <#
        If SQL Compare encounters any high level errors when parsing a scripts folder, it will exit with an error code of 62.
        Use /ignoreParserErrors to force SQL Compare to continue without exiting.
        #>
        [switch]$IgnoreParserErrors,

        [parameter()]
        <#
        When you are creating a scripts folder using /makescripts, SQL Compare automatically detects the case sensitivity of the data source.
        Use /ignoreSourceCaseSensitivity to disable automatic detection of case sensitivity.
        #>
        [switch]$IgnoreSourceCaseSensitivity,

        [parameter()]
        [ValidateSet('Additional ', 'Assembly', 'AsymmetricKey', 'Certificate', 'Contract', 'DdlTrigger', 'Different ', 'EventNotification', 'ExtendedProperty', 'FullTextCatalog', 'FullTextStoplist', 'Function', 'Identical ', 'MessageType', 'Missing ', 'PartitionFunction', 'PartitionScheme', 'Queue', 'Role', 'Route', 'Rule', 'Schema', 'SearchPropertyList', 'Sequence', 'Service', 'ServiceBinding', 'Static data ', 'StoredProcedure', 'SymmetricKey', 'Synonym', 'Table', 'User', 'UserDefinedType', 'View', 'XmlSchemaCollection')]
        <#
        Includes objects in the comparison. For example, to include tables:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /include:table
        To include specific objects, use a regular expression:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /include:table:Widget*
        For more examples using regular expressions, see Selecting tables with unrelated names.
        If you want to set up complex rules to include objects (eg to include tables with a specific name and owner), use a filter instead.
        To include more than one object or object type, use multiple /include switches:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /include:table:WidgetReferences /include:view
        If an object is matched by both /include and /exclude, the /exclude rule takes priority and the object is excluded.
        You can't use /include with the /project switch.
            Additional - Objects that aren't in the source (eg /db1).
            Missing - Objects that aren't in the target (eg /db2).
            Different - Objects that are the source and the target, but are different.
            Identical - Objects that are identical in the source and the target.
            StaticData - Static data in a source-controlled database or a scripts folder. Can't be used with snapshot data sources.
        To include object types, use:
            Assembly AsymmetricKey Certificate Contract DdlTrigger EventNotification ExtendedProperty
            FullTextCatalog FullTextStoplist Function MessageType PartitionFunction PartitionScheme Queue
            Role Route Rule Schema SearchPropertyList Sequence Service ServiceBinding StoredProcedure SymmetricKey
            Synonym Table User UserDefinedType View XmlSchemaCollection
        #>
        [string]$include,

        [parameter()]
        [Alias('log')]
        <#
        Creates a log file with a specified minimum log level.
        Log files collect information about the application while you are using it. These files are useful to us if you have encountered a problem. For more information, see Logging and log files.

        Arguments:
        None - Disables logging
        Error - Reports serious and fatal errors
        Warning - Reports warning and error messages
        Verbose - Reports all messages in the log file

        The default is None.
        For example:
            sqlcompare /db1:WidgetStaging /makeScripts:"D:\ScriptsFolder" /logLevel:Verbose

        You must use /logLevel each time you want a log file to be created.
        #>
        [ValidateSet('None', 'Error', 'Warning', 'Verbose')]
        [string]$LogLevel = 'None',

        [parameter()]
        <#
        Backs up the target database using Redgate SQL Backup Pro or SQL Server native.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /sync /makebackup
        #>
        [switch]$MakeBackup,

        [parameter()]
        [Alias('mkscr')]
        <#
        Creates a scripts folder from the data source.
            sqlcompare /db1:WidgetStaging /makeScripts:"C:\Scripts Folders\Widget staging scripts"
        If the folder already exists an error will occur. To merge scripts into an existing scripts folder, compare them with that folder and use the /synchronize switch:
            sqlcompare /scr1:"C:\Scripts Folders\Widget dev scripts" /scr2:"C:\Scripts Folders\Widget staging scripts" /synchronize
        For more information, see Working with scripts folders.
        #>
        [string]$MakeScripts,

        [parameter()]
        [Alias('mksnap')]
        <#
        Creates a snapshot from the data source.
        sqlcompare /db1:WidgetStaging /makeSnapshot:"C:\Widget Snapshots\StagingSnapshot.snp"
        If the file already exists an error will occur, unless you have also used the /force switch.
        #>
        [string]$MakeSnapshot,

        [parameter()]
        [Alias('o')]
        <#
        Applies the project configuration options used during comparison or deployment:
        sqlcompare /db1:WidgetStaging /db2:WidgetProduction /options:Default,IgnoreWhiteSpace
        For a detailed list of these options see Options used in the command line.
        #>
        [string]$Options,

        [parameter()]
        <#
        Redirects console output to the specified file:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /out:C:\output file
        #>
        [string]$Out,

        [parameter()]
        [Alias('outpr')]
        <#
        Writes the settings used for the comparison to the specified SQL Compare project file:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /options:Default,IgnoreWhiteSpace /outputProject:"C:\WidgetProject.scp"
        This also generates a SQL Compare project file. These files end with a .scp extension. If the file already exists an error will occur, unless you have also used the /force switch.
        #>
        [string]$OutputProject,

        [parameter()]
        <#
        Forces the width of console output.
        This can be used to ensure that database object names etc aren't truncated, and that SQL script lines aren't wrapped or broken.
        This is particularly useful when redirecting output to a file as it allows you to overcome the limitations of the default console width of 80 characters.
        #>
        [string]$OutputWidth,

        [parameter()]
        [Alias('p1')]
        <#
        The password for the source database.
        You must also provide a username. If you don't specify a username and password combination, integrated security is used:
            sqlcompare /db1:WidgetStaging /userName1:User1 /password1:P@ssw0rd /db2:WidgetProduction /userName2:User2 /password2:Pa$$w0rd
        This switch is only used if the source is a database. If the source is a backup, use /backupPasswords1
        #>
        [securestring]$Password1,

        [parameter()]
        [Alias('p2')]
        #The password for the target database.
        [securestring]$Password2,

        [parameter()]
        [Alias('pr')]
        <#
        Uses a SQL Compare project (.scp) file for the comparison.
        To use a project you have saved as "widgets.scp" from the command line:
            sqlcompare /project:"C:\SQLCompare\Projects\Widgets.scp"
        When you use a project, all objects that were selected for comparison when you saved the project are automatically included.
        When you use the command line, your project option selections are ignored and the defaults are used. Use /options to specify any additional options you want to use with a command line project.
        For more information, see Options used in the command line. If you want to include or exclude objects from an existing project, you must modify your selection using the graphical user interface.
        You can't use the /include and /exclude switches with /project.
        The /project switch is useful, for example, as you can't specify a custom filter in the command line, and specifying complex object selections using a regular expression can be unwieldy.
        For more information on using projects, and what a project contains, see Working with projects.
        #>
        [string]$Project,

        [parameter()]
        [Alias('q')]
        #Quiet mode: no output.
        [string]$Quiet,

        [parameter()]
        [Alias('r')]
        <#
        Generates a report and writes it to the specified file.
        The type of report is defined by the /reportType switch. If the file already exists an error will occur, unless you have used the /force switch:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /report:"C:\reports\WidgetReport.html" /reportType:Simple
        #>
        [string]$Report,

        [parameter()]
        [Alias('rad')]
        # Includes all objects with differences in the reports, rather than all selected objects.
        [string]$ReportAllObjectsWithDifferences,

        [parameter()]
        [Alias('rt')]
        [ValidateSet('XML', 'Simple', 'Interactive', 'Excel')]
        <#
        Arguments:
        XML - Simple XML report
        Simple - Simple HTML report
        Interactive - Interactive HTML report
        Excel - Microsoft Excel spreadsheet

        This switch defines the file format of the report produced by the /Report switch. The default setting is XML.
        For example:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /report:"C:\reports\WidgetReport.html" /reportType:Simple
        For more information, see Exporting the comparison results.
        #>
        [string]$ReportType,

        [parameter()]
        [Alias('r1')]
        <#
        Specifies the source control revision of the source database. To specify a revision, the database must be linked to SQL Source Control.
        To specify the latest version, type: HEAD
        Specifying a revision other than HEAD is only supported with TFS, SVN and Vault.
        If you're using another source control system, we recommend checking the revision out to a local folder and using the /Scripts1 switch.
        The following example compares revision 3 of WidgetStaging with the latest revision of WidgetProduction:
            sqlcompare /db1:WidgetStaging /revision1:3 /db2:WidgetProduction /revision2:HEAD
        #>
        [string]$Revision1,

        [parameter()]
        [Alias('r2')]
        # Specifies the source control revision of the target database. To specify a revision, the database must be linked to SQL Source Control.
        [string]$Revision2,

        [parameter()]
        [Alias('sf')]
        <#
        Generates a SQL script to migrate the changes which can be executed at a later time. If the file already exists an error will occur, unless you use the /force switch:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /scriptFile:"C:\Scripts Folder\WidgetSyncScript.sql"
        Scriptfile can be used when the target ( /db2, /scr2, /sn2 ) is a database, a snapshot, or a scripts folder.
        If the target is a snapshot or a scripts folder, the generated script modifies a database with the schema represented by that snapshot or scripts folder.
        #>
        [string]$ScriptFile,

        [parameter()]
        [Alias('scr1')]
        <#
        Specifies the scripts folder to use as the source:
            sqlcompare /scripts1:"C:\Scripts Folder\WidgetStagingScript" /db2:WidgetProduction
        #>
        [string]$Scripts1,

        [parameter()]
        [Alias('scr2')]
        # Specifies the scripts folder to use as the target.
        [string]$Scripts2,

        [parameter()]
        [Alias('sfx')]
        <#
        The path to a text file containing XML that describes the location of a source control repository.
        The method you use to create this file depends on which version of SQL Source Control you are working with:
        If you are using SQL Source Control 4 or earlier
        In the SSMS Object Explorer, right-click a source-controlled database and click Properties.
        In the Database Properties dialog box, click Extended Properties:

        Copy the XML fragment from the SQLSourceControl Scripts Location extended property.
        Create a new text file and paste the XML fragment into it.
        Save the file.
        If you are using SQL Source Control 5.4 or later
        In the SQL Source Control Setup tab for a source-controlled database, click on the Show link next to Under the hood
        Copy the XML fragment from the SQL Compare XML fragment block to the clipboard by clicking the Copy button:

        Create a new text file and paste the XML fragment into it.
        Save the file.
        #>
        [string]$ScriptsFolderXML,

        [parameter()]
        [Alias('s1', 'SourceServer')]
        <#
        Specifies the server on which the source (/db1:) database is located. If an explicit path isn't specified, it defaults to Local.
            sqlcompare /server1:Widget_Server\SQL2008 /db1:WidgetStaging /db2:WidgetProduction
        #>
        [string]$Server1,

        [parameter()]
        [Alias('s2', 'TargetServer')]
        # Specifies the server on which the target (/db2:) database is located. If an explicit path isn't specified, it defaults to Local.
        [string]$Server2,

        [parameter()]
        [Alias('warn')]
        <#
        Displays any warnings that apply to the deployment. For more information on warnings in SQL Compare, see Warnings.
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /showWarnings
        #>
        [switch]$ShowWarnings,

        [parameter()]
        [Alias('sn1')]
        <#
        Specifies the snapshot to use as the source:
            sqlcompare /snapshot1:"C:\Snapshots\WidgetStagingSnapshot.snp" /db2:WidgetProduction
        #>
        [string]$Snapshot1,

        [parameter()]
        [Alias('sn2')]
        <#
        Specifies the snapshot to use as the target:
            sqlcompare /db1:WidgetStaging /snapshot2:"C:\Snapshots\WidgetProductionSnapshot.snp"
        #>
        [string]$Snapshot2,

        [parameter()]
        <#
        Specifies a folder of source-controlled scripts to use as the source.
        If you use this switch, you must also specify /scriptsfolderxml.
        If you want to use a specific revision of the database, you can also specify /revision1.
            sqlcompare /sourcecontrol1 /revision1:100 /sfx:"C:\Files\scripts.txt" /db2:WidgetProduction
        #>
        [switch]$Sourcecontrol1,

        [parameter()]
        <#
        Specifies a folder of source-controlled scripts to use as the target.
        If you use this switch, you must also specify /scriptsfolderxml.
        If you want to use a specific revision of the database, you can also specify /revision2.
            sqlcompare db1:WidgetStaging /sourcecontrol2 /revision2:100 /sfx:"C:\Files\scripts.txt"
        #>
        [switch]$Sourcecontrol2,

        [parameter()]
        [Alias('sync', 'synchronise')]
        <#
        Synchronizes (deploys) the databases after comparison.
        The target (for example, /db2) is modified; the source (for example, /db1) isn't modified:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /synchronize
        #>
        [switch]$Synchronize,

        [parameter()]
        [Alias('senc')]
        [ValidateSet('UTF8', 'UTF8WithPreamble', 'Unicode', 'ASCII')]
        <#
        Arguments:
        UTF8 - UTF-8 encoding, without preamble
        UTF8WithPreamble - UTF-8 encoding, with 3-byte preamble
        Unicode - UTF-16 encoding
        ASCII - ASCII encoding

        Used with /scriptFile. Specifies the character encoding used when writing the SQL script file. The default is UTF8.
        For example:
            sqlcompare /db1:WidgetStaging /db2:WidgetProduction /scriptFile:"C:\Scripts Folder\WidgetSyncScript.sql" /syncScriptEncoding:ASCII
        #>
        [string]$SyncScriptEncoding,

        [parameter()]
        [Alias('til')]
        [ValidateSet('READ UNCOMITTED', 'READ COMMITTED', 'REPEATABLE READ', 'SNAPSHOT', 'SERIALIZABLE')]
        <#
        Specifies the transaction isolation level to set in the deployment script. For information about transaction isolation levels, see SET TRANSACTION ISOLATION LEVEL (MSDN).
        Arguments:
            READ UNCOMITTED
            READ COMMITTED
            REPEATABLE READ
            SNAPSHOT
            SERIALIZABLE
        #>
        [string]$TransactionIsolationLevel,

        [parameter()]
        [Alias('u1')]
        <#
        The username for the source database.
        If no username is specified, integrated security is used.
            sqlcompare /db1:WidgetStaging /userName1:User1 /password1:P@ssw0rd /db2:WidgetProduction /userName2:User2 /password2:Pa$$w0rd
        #>
        [string]$UserName1,

        [parameter()]
        [Alias('u2')]
        <#
        The username for the target database.
        If no username is specified, integrated security is used.
        #>
        [string]$UserName2,

        [parameter()]
        [Alias('vu1')]
        <#
        Specifies the username for the source control server linked to the source database.
            sqlcompare /db1:WidgetStaging /v1:3 /versionUserName1:User1 /vp1:P@ssw0rd /db2:WidgetProduction /v2:HEAD /versionUserName2:User2 /vp2:Pa$$w0rd
        If you have a username saved in SQL Source Control, you don't need to specify it in the command line.
        #>
        [string]$VersionUserName1,

        [parameter()]
        [Alias('vu2')]
        # Specifies the username for the source control server linked to the target database.
        [string]$VersionUserName2,

        [parameter()]
        [Alias('vp1')]
        <#
        Specifies the password for the source control server linked to the source database.
            sqlcompare /db1:WidgetStaging /v1:3 /vu1:User1 /versionpassword1:P@ssw0rd /db2:WidgetProduction /v2:HEAD /vu2:User2 /versionpassword2:Pa$$w0rd
        If you have a password saved in SQL Source Control, you don't need to specify it in the command line.
        #>
        [securestring]$VersionPassword1,

        [parameter()]
        [Alias('vp2')]
        # Specifies the password for the source control server linked to the target database.
        [securestring]$VersionPassword2,

        [parameter()]
        # This will tell the cmdlet to execute the command instead of printing out the command
        [switch] $Execute
    )
    BEGIN { }
    PROCESS
    {
        try
        {
            #These are the command line options that are not used as options and are not needed below
            $configuration = @('Execute', 'Verbose')
            $params = [ordered]@{}
            $arguments = ''

            #go get the information about the installation information
            Write-Verbose 'Getting installation info.'
            $installationInfo = Get-RedGateInstallationInfo -ApplicationName 'SQL Compare' -LatestVersion

            if (-not($installationInfo))
            {
                Write-Warning 'Unable to locate an installation of Redgate SQL Compare on this machine. Please ensure that the '
            }

            #this will give you the exec location
            $cmdPath = (Join-Path $installationInfo.InstallLocation $installationInfo.ExecutableName)

            $PSBoundParameters.GetEnumerator()| ForEach-Object {
                if ($_.Key -notin $configuration)
                {
                    $params.Add($_.Key, $_.Value)
                }
            }

            #Build the with string so that it can be added to the command
            foreach ($param in $params.GetEnumerator())
            {
                if ($param.Value)
                {
                    if ($param.Value.GetType().Name -eq 'SwitchParameter')
                    {
                        $arguments += "/$($param.Key.ToString().ToLower()) "
                    }
                    elseif ($param.Key.ToString() -eq 'SQLServerName')
                    {
                        $arguments += "/server:`"$($param.Value.ToString())`" "
                    }
                    elseif ($param.Value.GetType().Name -eq 'string')
                    {
                        $arguments += "/$($param.Key.ToString().ToLower()):`"$($param.Value.ToString())`" "
                    }
                    else
                    {
                        $arguments += "/$($param.Key.ToString().ToLower()):$($param.Value.ToString()) "
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess($installationInfo.ExecutableName, $arguments))
            {
                Start-Process -FilePath $cmdPath -ArgumentList $arguments -NoNewWindow
            }
        }
        catch
        {
            Write-Output $_.Exception.Message
            break;
        }
    }
    END { }
}