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
    Write-Host "Telepítési hiba: a futtatás 32 bites Windowson vagy 32 bites programból indítva nem támogatott" -ForegroundColor Red
    Read-Host "Enterre kilép:"
}