If ( [Environment]::Is64BitProcess ) {
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-module Join-Object -scope CurrentUser 
Install-module PSExcel -scope CurrentUser 
Install-module AzureAd -scope CurrentUser 
Install-Module PSFramework -scope CurrentUser 
Install-Module CredentialManager -scope CurrentUser
# For local AD mode:
#   Install Active Directory Module Powershell. Require Administrator rights and UAC elevation
#   Install by GUI (Add feature) or Powershell for W10 >=1809:
#Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
}
else {
    Write-Host "Telep�t�si hiba: a futtat�s 32 bites Windowson vagy 32 bites programb�l ind�tva nem t�mogatott" -ForegroundColor Red
    Read-Host "Enterre kil�p:"
}