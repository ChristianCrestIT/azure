#
# Check-VeeamBackupMs365.ps1
# Version 1.6
# christian.dahlberg@crestit.se
$logsource="CrestAuto"
New-EventLog -LogName Application -Source $logsource -ErrorAction Ignore
$runserver=$env:computername
$runuser=$env:USERNAME
$message = "Running Check-VeeamBackupMs365 on server:$runserver as user:$runuser"
Write-eventlog -logname Application  -Source $logsource -EventID 3900 -EntryType Information -message $message
Write-Output $message
$jobs=Get-VBOJob
foreach($job in $jobs)
{
    if($job.Laststatus -eq 'Warning')
    {
        $message = $job.name + " is in Warning state"
        Write-eventlog -logname Application  -Source $logsource -EventID 3901 -EntryType Warning -message $message
        Write-Output $message
    }
    if($job.Laststatus -eq 'Error')
    {
        $message = $job.name + " is in Error state"
        Write-eventlog -logname Application  -Source $logsource -EventID 3902 -EntryType Error -message $message
        Write-Output $message
    }
    if($job.Laststatus -eq 'Failed')
    {
        $message = $job.name + " is in Failed state"
        Write-eventlog -logname Application  -Source $logsource -EventID 3904 -EntryType Error -message $message
        Write-Output $message
    }
    if($job.Laststatus -eq 'Success')
    {
        $message = $job.name + " is in Success state"
        Write-eventlog -logname Application  -Source $logsource -EventID 3900 -EntryType Information -message $message
        Write-Output $message
    }


}
$lic=Get-VBOLicense|select *
if($lic.TotalNumber -lt $lic.UsedNumber)
{
    $message = "There is low count of payed licenses, used licences:" + $lic.UsedNumber + ", payed licenses:" + $lic.TotalNumber
    Write-eventlog -logname Application  -Source $logsource -EventID 3903 -EntryType Warning -message $message
    Write-Output $message
}
$message = "Finished running Check-VeeamBackupMs365 on server:$runserver as user:$runuser"
Write-eventlog -logname Application  -Source $logsource -EventID 3900 -EntryType Information -message $message
Write-Output $message