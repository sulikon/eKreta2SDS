[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-module Join-Object -scope CurrentUser 
Install-module PSExcel -scope CurrentUser 
Install-module AzureAd -scope CurrentUser 
Install-Module PSFramework -scope CurrentUser 
#Install-Module CredentialManager -scope CurrentUser
