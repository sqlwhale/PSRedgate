function Get-RedgateSQLBackupError
{
    <#
        .SYNOPSIS
            This cmdlet will allow you to look up errors from Redgate's website for sql backup.

        .DESCRIPTION
            Using a web scraper, you can pull down the error codes and dump them into a hash table.
            This cmdlet will pull down the codes and store it in a local file.

        .EXAMPLE
            Get-RedgateSQLBackupError -ErrorNumber 999

            This will return the full text name and description of the error that was returned from Redgate's documentation.

        .EXAMPLE
            Get-RedgateSQLBackupError -RefreshErrorCodes

            Will update the local cache used by this command by scraping Redgate's SQL Backup website for their documentation.
   #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        # The error number reported by the application that you would like to retrieve the description for.
        [int] $ErrorNumber,

        [Parameter()]
        # The error number reported by the application that you would like to retrieve the description for.
        [ValidateRange(6, 9)]
        [int] $SQLBackupVersionNumber = 9,

        [Parameter()]
        # Will instruct the cmdlet to pull a fresh list of error codes from the redgate website.
        [switch] $RefreshErrorCodes
    )
    BEGIN
    {
        $SQLBackupVersionDocumentationUrl = @{
            6 = 'https://documentation.red-gate.com/sbu6/errors-and-warnings/sql-backup-errors-500-5292'
            7 = 'https://documentation.red-gate.com/sbu7/errors-and-warnings/sql-backup-errors-500-5292'
            8 = 'https://documentation.red-gate.com/display/SBU8/SQL+Backup+errors+500+-+5292'
            9 = 'https://documentation.red-gate.com/sbu9/errors-and-warnings/sql-backup-errors-500-5292'
        }
        # loading private data from the module manifest
        $private:PrivateData = $MyInvocation.MyCommand.Module.PrivateData

        $errorList = $private:PrivateData['errorList']
        $dataLocation = $private:PrivateData['DataLocation']
        $cacheFile = "$dataLocation\errorList.xml"

        # if we were unable to pull in the error list from private data, let's go ahead and make sure that we know where the data file goes.
        if (-not($errorList))
        {
            # just in case the folder doesn't exist or gets deleted.
            if (-not(Test-Path $dataLocation))
            {
                New-Item -Path $dataLocation -ItemType Directory | Out-Null
            }

            # lets pull in our errors from a cache file if we can.
            Write-Verbose 'Loading error codes from cache file.'
            if (Test-Path $cacheFile)
            {
                $errorList = Import-Clixml -Path $cacheFile
            }
            else
            {
                Write-Verbose 'Unable to locate cache file.'
            }
        }
    }
    PROCESS
    {
        try
        {
            # this will pull new codes from redgate and overwrite the cached file.
            if ($RefreshErrorCodes -or -not($errorList))
            {
                Write-Verbose -Message "Pulling the latest values from Redgate SQL Backup Error Codes"
                $response = Invoke-WebRequest $SQLBackupVersionDocumentationUrl[$SQLBackupVersionNumber]

                $entries = ( $response.ParsedHtml.getElementsByTagName("table") | Select-Object -First 1 ).rows
                $table = @()
                foreach ($entry in $entries)
                {
                    if ($entry.tagName -eq "tr")
                    {
                        $thisRow = @()
                        $cells = $entry.children
                        forEach ($cell in $cells)
                        {
                            if ($cell.tagName -imatch "t[dh]")
                            {
                                if ($cell.innerText -eq 'Error code')
                                {
                                    $thisRow += "`"$($($cell.innerText -replace '"', "'") -replace "Error code",'ErrorCode')`""
                                }
                                else
                                {
                                    $thisRow += "`"$($cell.innerText -replace '"', "'")`""
                                }
                            }
                        }
                        $table += $thisRow -join ","
                    }
                }
                $errorList = $table | ConvertFrom-Csv
            }
            Write-Output $errorList | Where-Object ErrorCode -EQ $ErrorNumber | Select-Object -ExpandProperty Description
        }
        catch
        {
            Write-Output $_.Exception | Format-List -Force
            break
        }
    }
    END
    {
        #this will update the cache file if it hasn't been updated today
        if ((([System.IO.FileInfo]$cacheFile).LastWriteTime -le [DateTime]::Today) -or ($RefreshErrorCodes))
        {
            Write-Verbose "caching error codes to the file '$cacheFile'"
            $errorList | Export-Clixml -Path $cacheFile  -Encoding ASCII -Force
        }

        $private:PrivateData['errorList'] = $errorList
    }
}