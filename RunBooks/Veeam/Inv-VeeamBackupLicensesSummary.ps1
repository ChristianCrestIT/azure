#
# Inv-VeeamBackupLicensesSummary.ps1
# Version 2.1
# christian.dahlberg@crestit.se
$ErrorActionPreference="Stop"
$runserver=$env:computername
Write-output "Running Inv-VeeamBackupLicensesSummary on server:$runserver"
$TenantID=Get-AutomationVariable "EntraTenantID"
$ClientSecretCredential=Get-AutomationPSCredential "EntraIDGraphRead"
$mailcred=Get-AutomationPSCredential "MailCred"
$mailto=Get-AutomationVariable "VeeamBackupLicensSummaryReport"
Write-output "MailTo:$mailto"
$customername="UnimedicGroup"
$lics=@()
$from=$mailcred.username
$module=get-module Microsoft.Graph
if(!($module))
{
    Install-Module Microsoft.Graph -Force -AllowClobber -Scope AllUsers
}
Connect-MgGraph -ClientSecretCredential $ClientSecretCredential -TenantId $TenantID -NoWelcome
#$customers=Get-AzureADUser -all 1|group-object {$_.CompanyName}|select Name
$CurrentDate = Get-Date
$LastMonth = (($CurrentDate).AddMonths(-1)).ToUniversalTime().Month
$LastMonthYear = (($CurrentDate).AddMonths(-1)).ToUniversalTime().Year
$LastMonthName = $LastMonth | %{(Get-Culture).DateTimeFormat.GetMonthName($_)}
$LastMonthDays = [DateTime]::DaysInMonth($LastMonthYear, $LastMonth)
$StartOfPrevMonth = Get-Date -Month $LastMonth -Year $LastMonthYear -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0
$EndOfPrevMonth = ($StartOfPrevMonth).AddMonths(1).AddTicks(-1)
Write-output "FromDate:$StartOfPrevMonth"
Write-output "ToDate:$EndOfPrevMonth"
if(!(test-path -Path 'c:\temp\veeamlicens'))
{
    new-item -Path 'c:\temp\veeamlicens' -ItemType directory
}
Get-VBOLicenseOverviewReport -EndTime $EndOfPrevMonth -Format csv -Path c:\temp\veeamlicens -StartTime $StartOfPrevMonth
$file=get-childitem -Path c:\temp\veeamlicens -File
$users=import-csv -Path $file.FullName
Remove-Item -Path $file.fullname
#$users=Get-VBOLicensedUser
remove-variable -Name "VL*"
remove-variable -Name "UL*"
foreach($user in $users)
{
    $username=$user.'Account Name'
    write-output $username
    $azureuser=''
    $ErrorActionPreference='SilentlyContinue'
    $azureuser=Get-MgUser -userId $username -Property 'Mail, UserPrincipalName, CompanyName'| Select-Object DisplayName, UserPrincipalName, CompanyName
    $ErrorActionPreference='Stop'
    if($azureuser -ne '')
    {
        $company=$azureuser.CompanyName
    }
    else
    {
        $company='Unknown'
    }
    $varname="VL$company"
    $userlistvar="UL$company"
    if(!(get-Variable -Name $varname -ErrorAction Ignore))
    {
        New-Variable -Name $varname -Value 0
    }
    if(!(get-Variable -Name $userlistvar -ErrorAction Ignore))
    {
        New-Variable -Name $userlistvar -Value @()
    }
    $newval=(Get-Variable -Name $varname).Value + 1
    #Invoke-Expression "'$userlistvar += $username'"
    $newuserlist=""
    $newuserlist=(Get-Variable -Name $userlistvar).Value + "$username"
    set-variable -name $varname -Value $newval
    set-variable -name $userlistvar -Value $newuserlist
}
$vars=get-variable|where {$_.Name -like "VL*"}
foreach($var in $vars)
{
    $department=$var.name
    $department=$department.replace('VL','')
    Write-output "Sending mail for department:$department"
    [string]$body=""
    $body+="This is an summary of the Veeamlicensusage at the customer:$customername`r`n"
    $body+="`r`n"
    $body+="Department:$department`r`n"
    $count=$var.Value
    $body+="Count:$count`r`n"
    $body+="`r`n"
    #$body+="$newuserlist"
    
    $userlistvar="UL$department"
    $userlists=(Get-Variable -Name $userlistvar).Value
    foreach($userlist in $userlists)
    {
        $body+=$userlist|out-string    
    }
    if($body -ne "")
    {
        Send-MailMessage -To $mailto -Credential $mailcred -from $from -SmtpServer "smtp.office365.com" -Subject "$customern Veeam Office 365 Backup Licens Summary Report $customername" -body $body -Port 587 -UseSsl -erroraction Stop
    }



}
Disconnect-MgGraph

