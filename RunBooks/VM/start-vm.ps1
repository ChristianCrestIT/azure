param(
	[parameter(Mandatory=$true)]
	$VmName = "",
    [parameter(Mandatory=$true)]
	$RgName = ""
)

try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
$azVMs = Get-AzVM -Name $VmName -ResourceGroupName $RgName
$azVMS | Start-AzVM
