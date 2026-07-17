<#
Inv-EntraIdManagers.ps1
.SYNOPSIS
Checks users in Entra ID that manager is assigned
Runs in Azure Automation Runbook on Hybrid Worker

.EXAMPLE
Should only be running in Runbook

.NOTES
Version: 0.1
Author: christian.dahlberg@crestit.se
Requires:
- PowerShell 3.0 or higher
- Microsoft.Graph.Authentication Module
- Microsoft.Graph.Users Module
#>
$runserver=$env:computername
Write-Output $runserver
$runuser=$env:USERNAME
$logsource="CrestAuto"
$from='support@crestit.se'
$mailcred=Get-AutomationPSCredential "MailCred"
$TenantID=Get-AutomationVariable "EntraTenantID"
$ClientSecretCredential=Get-AutomationPSCredential "EntraIDGraphRead"
$message = "Running Inv-EntraIdManagers on server:$runserver as user:$runuser"
write-out $message
New-EventLog -LogName Application -Source $logsource -ErrorAction Ignore
Write-eventlog -logname Application  -Source $logsource -EventID 6100 -EntryType Information -message $message
#region ADusers
    $users = get-aduser -SearchBase $SearchBase -Filter {(enabled -eq $true)} -Properties Name
    foreach($user in $users)
    {
    
    $manager=$user.name
    $email=$user.UserPrincipalName
    $message = "Found user $manager checking"
    Write-eventlog -logname Application  -Source $logsource -EventID 6100 -EntryType Information -message $message
    $reports = Get-ADUser -Identity $user.SamAccountName -Properties directreports | select-object -ExpandProperty DirectReports
    if($reports)
    {
        $count=0
        [string]$body=""
        $body+="You are put as manager for the following account(s)<br />"
        $body+="Please verify and report any errors<br />"
        $body+="You can respond to this email to report<br />"
        $body+="<br />"
        foreach($report in $reports)
        {
            
            $name=get-aduser $report
            if($name.Enabled -eq $true)
            {
                $message = "Found user $[user.name] adding to report"
                Write-eventlog -logname Application  -Source $logsource -EventID 6100 -EntryType Information -message $message
                $count=1
                $username=$name.name
                $body+="$username<br />"
            }
        }

        if($count -eq 1)
        {
            $message = "Sending mail to $email"
            Write-eventlog -logname Application  -Source $logsource -EventID 6100 -EntryType Information -message $message
            Send-MailMessage -To $email -from $from -SmtpServer "crestit-se.mail.protection.outlook.com" -Subject "Users for $manager" -body $body -Port 25 -UseSsl -Encoding UTF8 -erroraction Stop -BodyAsHtml
        }
    }
}

#endregion
#region AAD guests
$from='support@crestit.se'
$email='support@crestit.se'
connect-azuread -credential $aadcred
$guests=Get-AzureADUser -Filter "userType eq 'Guest'" -All $true | Select-Object DisplayName, UserPrincipalName, objectid
foreach($guest in $guests)
{
    $manager=get-azureadusermanager -objectid $guest.objectid
    if(!$manager)
    {
        [string]$body=""
        $username=$guest.UserPrincipalName
        $body+="Guestuser $username has no manager<br />"
        $body+="Please correct<br />"
        $message = "Found $username with no manager"
        Write-eventlog -logname Application  -Source $logsource -EventID 6101 -EntryType Warning -message $message
        Send-MailMessage -To $email -from $from -credential $mailcred -SmtpServer "smtp.office365.com" -Subject "Guestuser has no manager" -body $body -Port 587 -UseSsl -Encoding UTF8 -erroraction Stop -BodyAsHtml
    }
}
$users = get-AzureADUser -Filter "accountEnabled eq true and userType eq 'Member'" -all $true
foreach($user in $users)
{
    
    $manager=$user.Displayname
    $email=$user.UserPrincipalName
    $reports = Get-AzureADUserDirectReport -objectid $user.objectid
    if($reports)
    {
        $count=0
        [string]$body=""
        $body+="You are put as manager for the following account(s)<br />"
        $body+="Please verify and report any errors<br />"
        $body+="You can respond to this email to report<br />"
        $body+="<br />"
        foreach($report in $reports)
        {
            if($report.UserType -eq 'Guest')
            {    
                $message = "Found user $[user.name] adding to report"
                #Write-eventlog -logname Application  -Source $logsource -EventID 6100 -EntryType Information -message $message
                $count=1
                $username=$report.Displayname
                $body+="$username<br />"
            }
        }
        if($count -eq 1)
        {
            $message = "Sending mail to $email"
            #Write-eventlog -logname Application  -Source $logsource -EventID 6100 -EntryType Information -message $message
            #Send-MailMessage -To 'christian.dahlberg@crestit.se' -from $from -SmtpServer "crestit-se.mail.protection.outlook.com" -Subject "Users for $manager" -body $body -Port 25 -UseSsl -Encoding UTF8 -erroraction Stop -BodyAsHtml
            Send-MailMessage -To $email -from $from -SmtpServer "crestit-se.mail.protection.outlook.com" -Subject "Users for $manager" -body $body -Port 25 -UseSsl -Encoding UTF8 -erroraction Stop -BodyAsHtml
        }
    }
}
disconnect-azuread
#endregion
#region Aad users






#endregion
$message = "Finished running Inv-Managers"
Write-eventlog -logname Application  -Source $logsource -EventID 6100 -EntryType Information -message $message

