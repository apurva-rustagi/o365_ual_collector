#Modify the values for the following variables to configure the audit log search.
$engagement = Read-Host "Please enter engagement name "
[DateTime]$start = Read-Host "Please start date in mm/dd/yyyy hh:mm:ss (24 hours) format "
[DateTime]$end = Read-Host "Please end date in mm/dd/yyyy hh:mm:ss (24 hours) format "
$userid = Read-Host "Please enter usernames. Use Comma if multiple users. Please leave it empty if you want data for all users. "
if ($userid -eq [string]::empty)
{
	Write-Host "No users provided. The script will fetch logs for all users" -foregroundColor Yellow
	$userid = $null
}

$logFile = "AuditLogSearchLog_" + $engagement + ".txt"
$outputFile = "AuditLogRecords_"+ $engagement + ".csv"
#[DateTime]$start = [DateTime]::UtcNow.AddDays(-90)
#[DateTime]$end = [DateTime]::UtcNow
#[DateTime]$start = "09/14/2021 19:13:39"
#[DateTime]$end = [DateTime]::UtcNow
$resultSize = 5000
$intervalMinutes = 60
$record = $null

#Start script
[DateTime]$currentStart = $start
[DateTime]$currentEnd = $start

Function Write-LogFile ([String]$Message)
{
    $final = [DateTime]::Now.ToUniversalTime().ToString("s") + ":" + $Message
    $final | Out-File $logFile -Append
}

Write-LogFile "BEGIN: Retrieving audit records between $($start) and $($end), RecordType=$record, PageSize=$resultSize."
Write-Host "Retrieving audit records for the date range between $($start) and $($end), RecordType=$record, ResultsSize=$resultSize"

$totalCount = 0
while ($true)
{
    $currentEnd = $currentStart.AddMinutes($intervalMinutes)
    if ($currentEnd -gt $end)
    {
        $currentEnd = $end
    }

    if ($currentStart -eq $currentEnd)
    {
        break
    }

    $sessionID = [Guid]::NewGuid().ToString() + "_" +  "ExtractLogs" + (Get-Date).ToString("yyyyMMddHHmmssfff")
    Write-LogFile "INFO: Retrieving audit records for activities performed between $($currentStart) and $($currentEnd) using sessionID $sessionID"
    Write-Host "Retrieving audit records for activities performed between $($currentStart) and $($currentEnd) using sessionID $sessionID"
    $currentCount = 0

    $sw = [Diagnostics.StopWatch]::StartNew()
    do
    {
        $results = Search-UnifiedAuditLog -StartDate $currentStart -UserIds $userid -EndDate $currentEnd -SessionId $sessionID -SessionCommand ReturnLargeSet -ResultSize $resultSize

        if (($results | Measure-Object).Count -ne 0)
        {
            $results | export-csv -Path $outputFile -Append -NoTypeInformation

            $currentTotal = $results[0].ResultCount
            $totalCount += $results.Count
            $currentCount += $results.Count
            Write-LogFile "INFO: Retrieved $($currentCount) audit records out of the total $($currentTotal)"

            if ($currentTotal -eq $results[$results.Count - 1].ResultIndex)
            {
                $message = "INFO: Successfully retrieved $($currentTotal) audit records for the current time range. Moving on!"
                Write-LogFile $message
                Write-Host "Successfully retrieved $($currentTotal) audit records for the current time range. Moving on to the next interval." -foregroundColor Yellow
                ""
                break
            }
        }
    }
    while (($results | Measure-Object).Count -ne 0)

    $currentStart = $currentEnd
}

Write-LogFile "END: Retrieving audit records between $($start) and $($end), RecordType=$record, PageSize=$resultSize, total count: $totalCount."
Write-Host "Script complete! Finished retrieving audit records for the date range between $($start) and $($end). Total count: $totalCount" -foregroundColor Green