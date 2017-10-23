function Get-RedgateSQLBackupError
{
    <#
        .SYNOPSIS
            This cmdlet will allow you to look up errors from Redgate's website for sql backup.
        .DESCRIPTION
            Using a web scraper, you can pull down the error codes and dump them into a hash table.
            This cmdlet will pull down the codes and store it in a local file.
        .EXAMPLE
   #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        # The error number reported by the application that you would like to retrieve the description for.
        [int] $ErrorNumber,

        [Parameter()]
        # Will instruct the cmdlet to pull a fresh list of error codes from the redgate website.
        [switch] $RefreshErrorCodes
    )
    BEGIN
    {
        # loading private data from the module manifest
        $private:PrivateData = $MyInvocation.MyCommand.Module.PrivateData
        $cacheFile = '..\data\errorList.xml'
        $errorList = $private:PrivateData['errorList']

        if (-not($errorList))
        {
            Write-Verbose 'Loading error codes from cache file.'
            $errorList = Import-Clixml -Path $cacheFile
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
                $response = Invoke-WebRequest 'https://documentation.red-gate.com/display/SBU7/SQL+Backup+errors+500+-+5292'

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
            Write-Host  $_.Exception | Format-List -Force
            break
        }
    }
    END
    {
        #this will update the cache file if it hasn't been updated today
        if (([System.IO.FileInfo]$cacheFile).LastWriteTime -le [DateTime]::Today)
        {
            Write-Verbose "caching error codes to the file '$cacheFile'"
            $errorList | Export-Clixml -Path $cacheFile  -Encoding ASCII -Force
        }

        $private:PrivateData['errorList'] = $errorList
    }
}