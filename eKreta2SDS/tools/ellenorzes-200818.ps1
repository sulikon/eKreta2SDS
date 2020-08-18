[CmdletBinding()]
Param (
    [Parameter()][String]$StoredCredential = "" # Stored credential name in Windows Credential Manager
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
install-module msonline -scope CurrentUser

        

import-module msonline

Write-Host "Bejelentkezés..."

if ($StoredCredential -ne "") {
        $AzureCredential = Get-StoredCredential -Target $StoredCredential
        if (!$AzureCredential) {
           $null = Get-Credential | New-StoredCredential -Target $StoredCredential
           $AzureCredential = Get-StoredCredential -Target $StoredCredential
        }
}

try {
    if ($AzureCredential) {
            $null = Connect-MsolService -Credential $AzureCredential -ErrorAction Stop
    }
    else {
            $null = Connect-MsolService -ErrorAction Stop
    }
    $initialdomain = (Get-MsolCompanyInformation).InitialDomain
    if (![string]::IsNullOrWhiteSpace($initialdomain)) {
        Write-Host "Sikeres bejelentkezés, környezet: ",$initialdomain
    }
}
catch {
            Write-Host "Bejelentkezési hiba, kilépek."
            exit
}

$companytags=(Get-MsolCompanyInformation).companytags
$hasedutag = $false
$edutag = ""
$edutagapproved = $false
foreach ($i in $companytags) {
  $t= $i.Split("=")
  if ($t[0] -eq "edu.microsoft.com/edu") {
    $hasedutag = $true
    $edutag = $t[1]
    if ($edutag -eq "approved") {
        $edutagapproved = $true
    }
  }
}

If ($edutagapproved) {
    Write-Host "Oktatási jogosultság: OK" -ForegroundColor Green
}
else {
    Write-Host "Oktatási jogosultság: nincs visszaigazolva" -ForegroundColor Yellow
    Write-Host "Részletek:"
    Write-Host "EDU TAG létezik? ",$hasedutag
    if (![string]::IsNullOrWhiteSpace($edutag)) {
        Write-Host "EDU TAG értéke: ", $edutag
    }
    Write-Host "Következő lépés: igazolja az oktatási jogosultságot a https://sulikon.freshdesk.com/a/solutions/articles/62000202662 cikk lépéseit követve."
}

# licencek lekérdezése
[array]$licencek = Get-MsolAccountSku

# A1 és A1 Plus diák és tanári licencek azonosítójának lekérdezése
$RegiDiakLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_STUDENT" } | Select-Object -First 1).AccountSkuId
$UjDiakLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_IW_STUDENT" } | Select-Object -First 1).AccountSkuId
$RegiTanarLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_FACULTY" } | Select-Object -First 1).AccountSkuId
$UjTanarLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_IW_FACULTY" } | Select-Object -First 1).AccountSkuId

$domainek = Get-MsolDomain
$sulidhuexists = $false
$sulidhuverified = $false
foreach ($domain in $domainek) {
    if ($domain.Name -match ".sulid.hu") {
        $sulidhuexists = $true
        if ($domain.Status -eq "Verified") {
            $sulidhuverified = $true
        }
    }
} 


if ([string]::IsNullOrWhiteSpace($UjTanarLicenc) -or [string]::IsNullOrWhiteSpace($UjDiakLicenc)) {
    Write-Host "Office 365 A1 Plus diák és tanár licencek: nincsenek meg" -ForegroundColor Yellow
    Write-Host "Részletek:"
    Write-Host "Office 365 A1 Plus for Faculty licenc létezik? ",(![string]::IsNullOrWhiteSpace($UjTanarLicenc))
    Write-Host "Office 365 A1 Plus for Students licenc létezik? ",(![string]::IsNullOrWhiteSpace($UjDiakLicenc))
    Write-Host "sulid.hu DNS domain létezik a környezetben? ",$sulidhuexists
    Write-Host "sulid.hu DNS domain ellenőrzött? ",$sulidhuverified
    if ($sulidhuverified) {
       Write-Host "Következő lépés: hozza létre a végleges oktatási licenceket a https://sulikon.freshdesk.com/a/solutions/articles/62000080221 cikk lépéseit követve."
    }
    else {
        if ($sulidhuexists) {
            Write-Host "Következő lépés: ellenőrizze a DNS domain hozzáadását a https://admin.microsoft.com/AdminPortal/Home#/Domains oldalon, majd futtassa újra ezt az ellenőrző programot."
        }
        else {
            Write-Host "Következő lépés: igényelje a Microsofttól a végleges oktatási licenceket a https://sulikon.freshdesk.com/a/solutions/articles/62000206169 cikk lépéseit követve."
        }
    }
    
}
else {
    Write-Host "Office 365 A1 Plus diák és tanár licencek: OK" -ForegroundColor Green
}

$RegiDiakLicencCount = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_STUDENT" } | Select-Object -First 1).ConsumedUnits
$RegiTanarLicencCount = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_FACULTY" } | Select-Object -First 1).ConsumedUnits

if ($RegiDiakLicencCount+$RegiTanarLicencCount -gt 0) {
    Write-Host "Office 365 A1 diák és tanár licencek használaton kívül: még nem" -ForegroundColor Yellow
    Write-Host "Részletek:"
    Write-Host "Office 365 A1 for Faculty licencek használatban: ",$RegiTanarLicencCount
    Write-Host "Office 365 A1 for Students licencek használatban: ",$RegiDiakLicencCount
    if ([string]::IsNullOrWhiteSpace($UjTanarLicenc) -or [string]::IsNullOrWhiteSpace($UjDiakLicenc)) {
        Write-Host "Következő lépés: győződjön meg róla, hogy az A1 Plus tanári és diáklicencek rendelkezésre állnak, majd futtassa újra ezt a programot."
    }
    else {
        Write-Host "Következő lépés: cserélje le az A1 licenceket végleges A1 Plus licencekre a https://sulikon.freshdesk.com/a/solutions/articles/62000150184 cikk lépéseit követve."
    }
}
else {
    Write-Host "Office 365 A1 diák és tanár licencek használaton kívül: OK" -ForegroundColor Green
} 

Read-Host -Prompt "Üssön ENTER-t a kilépéshez!"