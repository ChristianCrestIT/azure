<#
Check-EntraIdUsers.ps1
.SYNOPSIS
Checks users in Entra ID that manager is assigned
Runs in Azure Automation Runbook on Hybrid Worker

.PARAMETER checkguestnomanager


.EXAMPLE
Should only be running in Runbook

.NOTES
Version: 0.2
Author: christian.dahlberg@crestit.se
Requires:
- PowerShell 3.0 or higher
- Microsoft.Graph.Authentication Module
- Microsoft.Graph.Users Module
#>
param(
	[parameter(Mandatory=$false)]
	[boolean] $checkguestnomanager = $true,
    [parameter(Mandatory=$false)]
	[boolean] $checkusernomanager = $true,
    [parameter(Mandatory=$false)]
	$UserNoManagerExclude = @("johan.frodin@unimedic.se"),
    [parameter(Mandatory=$false)]
	[boolean] $CheckLastLoggedIn= $false,
    [parameter(Mandatory=$false)]
	[Array] $UserLastLoggedInExclude = @('sqlserver@unimedicpharma.se','easysend@unimedicpharma.se','sqlserver2@unimedicpharma.se'),
    [parameter(Mandatory=$false)]
	[int] $CheckLastLoggedInDays= -90
)
#$CustomerId=Get-AutomationVariable "customerLogID"
#$SharedKey=Get-AutomationVariable "LogSpaceKey"
$TenantID=Get-AutomationVariable "EntraTenantID"
$ClientSecretCredential=Get-AutomationPSCredential "EntraIDGraphRead"
$logsource="CrestAuto"
$Global:LogType = "Users"
$TimeStampField = "TimeGenerated"
$TimeGenerated = [DateTime]::UtcNow.ToString("r")
$whoami = whoami
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}
Function Post-OMSData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -fileName $fileName `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    Write-Output $response.StatusCode

}
function checkguestnomanager{
    Connect-MgGraph -ClientSecretCredential $ClientSecretCredential -TenantId $TenantID -NoWelcome
    $guests=Get-MgUser -Filter "userType eq 'Guest'"| Select-Object DisplayName, UserPrincipalName, id, mail
    foreach($guest in $guests)
    {
        $manager=get-mgusermanager -userid $guest.id -erroraction SilentlyContinue
        if(!$manager)
        {
            $message = "Guest $($guest.mail) has no Manager"
            Write-Output $message
            Write-eventlog -logname Application  -Source $logsource -EventID 3130 -EntryType Warning -message $message
        }
    }
    Disconnect-MgGraph
}
Function checkusernomanager{
    Connect-MgGraph -ClientSecretCredential $ClientSecretCredential -TenantId $TenantID -NoWelcome
    $Members=Get-MgUser -All -Filter "userType eq 'Member' and accountEnabled eq true and OnPremisesSyncEnabled ne true" -ConsistencyLevel eventual -CountVariable CountVar| Select-Object DisplayName, UserPrincipalName, id, mail
    #$members=Get-MgUser -Filter "userType eq 'Member' and accountEnabled eq true" -ConsistencyLevel eventual| Select-Object DisplayName, UserPrincipalName, id, mail
    foreach($member in $members)
    {
        if($member.mail -in $UserNoManagerExclude)
        {
            continue
        }
        $manager=get-mgusermanager -userid $member.id  -erroraction SilentlyContinue
        if(!$manager)
        {
            $message = "User $($Member.UserPrincipalName) has no Manager"
            Write-Output $message
            Write-eventlog -logname Application  -Source $logsource -EventID 3131 -EntryType Warning -message $message
        }
    }
    Disconnect-MgGraph
}
$message = "Running Check-EntraIdUsers"
Write-Output $message
if($checkguestnomanager -eq $true)
{
    $message = "Check-EntraIdUsers running Guests with no manager"
    Write-Output $message
    checkguestnomanager
}
if($checkusernomanager -eq $true)
{
    $message = "Check-EntraIdUsers running Users with no manager"
    Write-Output $message
    checkusernomanager
}
if($CheckLastLoggedIn -eq $true)
{
    $message = "Check-EntraIdUsers running CheckLastLoggedIn"
    Write-Output $message
    CheckLastLoggedIn
}
$message = "Finnished running Check-EntraIdUsers"
Write-Output $message
