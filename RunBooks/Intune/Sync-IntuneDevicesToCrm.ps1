#
# Sync-IntuneDevicesToCrm.ps1
# Version 1.9
# christian.dahlberg@crestit.se
# Runs in Azure
function Get-OsVersion
{
    Param(
        [string]$buildNUMBER
    )
    If($buildnumber -like "*26200*")
    {
        Return "Windows 11 25H2"
    }
    
    If($buildnumber -like "*26100*")
    {
        Return "Windows 11 24H2"
    }
    If($buildnumber -like "*22631*")
    {
        Return "Windows 11 23H2"
    }
    If($buildnumber -like "*22621*")
    {
        Return "Windows 11 22H2"
    }
    If($buildnumber -like "*22000*")
    {
        Return "Windows 11 21H2"
    }
    elseif($buildnumber -like "*19045*")
    {
        Return "Windows 10 22H2"
    }
    elseIf($buildnumber -like "*19044*")
    {
        Return "Windows 10 21H2"
    }
    ElseIf($buildnumber -like "*19043*")
    {
        Return "Windows 10 21H1"
    }
    ElseIf($buildnumber -like "*19042*")
    {
        Return "Windows 10 20H2"
    }
    elseIf($buildnumber -like "*19041*")
    {
        Return "Windows 10 2004"
    }
    elseIf($buildnumber -like "*17134*")
    {
        Return "Windows 10 1803"
    }
    elseIf($buildnumber -like "*17763*")
    {
        Return "Windows 10 1809"
    }
    else
    {
        return $buildNUMBER
    }
}
$AzureADCred=Get-AutomationPSCredential "AzureADCred"
$IntuneReadAppID=Get-AutomationVariable 'IntuneReadAppID'
$tenantId=Get-AutomationVariable 'CrestCRMTeantid'
$clientId=Get-AutomationVariable 'CrestCRMclientid'
$clientSecret=Get-AutomationVariable 'CrestCRMclientsecret'
$environmentUrl=Get-AutomationVariable 'CrestCRMurl'
$tableName=Get-AutomationVariable 'CrestCRMtablename'
$tableNameid=Get-AutomationVariable 'CrestCRMtableid'
$apiUrl = "$environmentUrl/api/data/v9.1/$tableName"
$message = "Running Sync-IntuneDevices"
Write-Output $message
$module=get-module -Name Microsoft.Graph.Intune -ErrorAction Ignore
if(!$module)
{
    $provider = Get-PackageProvider NuGet -ErrorAction Ignore
    if (-not $provider)
    {
        Write-output "Installing provider NuGet"
        Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
    }
    Write-output "Installing graph module"
    Install-Module Microsoft.Graph.Intune -Force -AllowClobber
}
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = $environmentUrl
}
$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
$accessToken = $tokenResponse.access_token
Update-MSGraphEnvironment -AppId $IntuneReadAppID
Connect-MSGraph -Credential $azureadcred 
$devices=Get-IntuneManagedDevice
foreach($device in $devices)
{
    $id=$device.id
    $serienummer=$device.serialnumber
    $eid=$device.azureADDeviceId
    $visningsnamn=$device.devicename
    $model=$device.model
    $manufacturer=$device.manufacturer
    $user=$device.userprincipalname
    $OS=$device.operatingSystem
    $osbuild=$device.osVersion
    $OsVersion=Get-OsVersion -buildNUMBER $osbuild
    if($device.deviceCategoryDisplayName -like '*dator*')
    {
        $type="dator"
    }
    elseif($device.deviceCategoryDisplayName -like '*mobil*')
    {
        $type="MobilTelefon"
    }
    else
    {
        $type=""
    }
    if($serienummer -and $serienummer -ne '0')
    {
        $filter = "cr507_serienummer eq '$serienummer'"
    }
    else
    {
        $filter = "cr507_entradeviceid eq '$eid'"
    }
    $searchUrl = $apiUrl + '?$filter=' + $filter
    $existingEntry = Invoke-RestMethod -Uri $searchUrl -Method Get -Headers @{
        "Authorization" = "Bearer $accessToken"
        "Accept"        = "application/json"
    } -ContentType 'application/json; charset=utf-8'
    $body = @{
        "cr507_visningsnamn" = $visningsnamn
        "cr507_serienummer" = $serienummer
        "cr507_anvandare" = $user
        "cr507_modell" = $model
        "cr507_tillverkare" = $manufacturer
        "cr507_intune_serial" =$id
        "cr507_osversion" = $OsVersion
        "cr507_entradeviceid"=$eid
        "cr507_kalla" = "Intune-Sync"
        "cr507_manageringsmetod" = "831490000"
    } | ConvertTo-Json -Depth 10
    if ($existingEntry.value.Count -gt 0) {
        # Om posten finns, uppdatera den
        $recordId = $existingEntry.value[0].$tableNameid  # H�mta ID fr�n befintlig post
        $updateUrl = "$apiUrl($recordId)"
        Invoke-RestMethod -Uri $updateUrl -Method Patch -Body $body -Headers @{
            "Authorization" = "Bearer $accessToken"
            "Accept"        = "application/json"
        } -ContentType 'application/json; charset=utf-8'
        Write-Output "Posten med visningsnamn '$visningsnamn' har uppdaterats."
    } 
    else {
        # Om posten inte finns, skapa en ny
        Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -Headers @{
            "Authorization" = "Bearer $accessToken"
            "Accept"        = "application/json"
        } -ContentType 'application/json; charset=utf-8'
        Write-Output "Ny post skapad med visningsnamn '$visningsnamn'."
    }
}
$message = "Finished running Sync-IntuneDevices"
Write-Output $message