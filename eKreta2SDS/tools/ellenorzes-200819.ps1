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

# előfizetések lekérdezése
[array]$elofizetesek = Get-MsolSubscription
$A1TanarVeglegesCount = 0
$A1DiakVeglegesCount = 0
$A1PlusTanarVeglegesCount = 0
$A1PlusDiakVeglegesCount = 0
$A1DiakProbaCount = 0
$A1TanarProbaCount = 0
foreach ($elofizetes in $elofizetesek) {
    if ($elofizetes.SkuPartNumber -eq "STANDARDWOFFPACK_FACULTY") {
        if (($elofizetes.Status -eq "Enabled") -and (!$elofizetes.IsTrial)) {
            $A1TanarVeglegesCount += $elofizetes.TotalLicenses
        }
    }
    if ($elofizetes.SkuPartNumber -eq "STANDARDWOFFPACK_STUDENT") {
        if (($elofizetes.Status -eq "Enabled") -and (!$elofizetes.IsTrial)) {
            $A1DiakVeglegesCount += $elofizetes.TotalLicenses
        }
    }
    if ($elofizetes.SkuPartNumber -eq "STANDARDWOFFPACK_IW_FACULTY") {
        if (($elofizetes.Status -eq "Enabled") -and (!$elofizetes.IsTrial)) {
            $A1PlusTanarVeglegesCount += $elofizetes.TotalLicenses
        }
    }
    if ($elofizetes.SkuPartNumber -eq "STANDARDWOFFPACK_IW_STUDENT") {
        if (($elofizetes.Status -eq "Enabled") -and (!$elofizetes.IsTrial)) {
            $A1PlusDiakVeglegesCount += $elofizetes.TotalLicenses
        }
    }
    if ($elofizetes.SkuPartNumber -eq "STANDARDWOFFPACK_FACULTY") {
        if (($elofizetes.Status -eq "Enabled") -and ($elofizetes.IsTrial)) {
            $A1TanarProbaCount += $elofizetes.TotalLicenses
        }
    }
    if ($elofizetes.SkuPartNumber -eq "STANDARDWOFFPACK_STUDENT") {
        if (($elofizetes.Status -eq "Enabled") -and ($elofizetes.IsTrial)) {
            $A1DiakProbaCount += $elofizetes.TotalLicenses
        }
    }
} 

if (($A1TanarVeglegesCount + $A1PlusTanarVeglegesCount -eq 0) -or ($A1DiakVeglegesCount + $A1PlusDiakVeglegesCount -eq 0)) {
    Write-Host "Office 365 véglegeges diák és tanár licencek: nincsenek meg" -ForegroundColor Yellow
    Write-Host "Részletek:"
    Write-Host "Végleges Office 365 A1 Plus for Faculty licencek száma:",($A1PlusTanarVeglegesCount)
    Write-Host "Végleges Office 365 A1 Plus for Students licencek száma:",($A1PlusDiakVeglegesCount)
    Write-Host "Végleges Office 365 A1 for Faculty licencek száma:",($A1TanarVeglegesCount)
    Write-Host "Végleges Office 365 A1 for Students licencek száma:",($A1DiakVeglegesCount)
    Write-Host "Lejáró, próbaveriós Office 365 A1 for Faculty licencek száma:",($A1TanarProbaCount)
    Write-Host "Lejáró, próbaveriós Office 365 A1 for Students licencek száma:",($A1DiakProbaCount)
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
    Write-Host "Office 365 végleges diák és tanár licencek: OK" -ForegroundColor Green
    if ($A1PlusTanarVeglegesCount + $A1PlusDiakVeglegesCount -eq 0) {
        Write-Host "Információ: az iskola jogosult a telepíthető Office csomagot is tartalmazó A1 Plus licencek használatára is. Igényelheti a Microsofttól a végleges oktatási licenceket a https://sulikon.freshdesk.com/a/solutions/articles/62000206169 cikk lépéseit követve."
    }
}

$RegiDiakLicencCount = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_STUDENT" } | Select-Object -First 1).ConsumedUnits
$RegiTanarLicencCount = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_FACULTY" } | Select-Object -First 1).ConsumedUnits

if ((($A1TanarVeglegesCount -eq 0) -and ($RegiTanarLicencCount -gt 0)) -or (($A1DiakVeglegesCount -eq 0) -and ($RegiDiakLicencCount -gt 0))) {
    Write-Host "Lejáró, próbaverziós Office 365 A1 diák és tanár licencek használaton kívül: még nem" -ForegroundColor Yellow
    Write-Host "Részletek:"
    Write-Host "Lejáró, próbaverziós Office 365 A1 for Faculty licencek használatban: ",$RegiTanarLicencCount
    Write-Host "Lejáró, próbaverziós Office 365 A1 for Students licencek használatban: ",$RegiDiakLicencCount
    if ([string]::IsNullOrWhiteSpace($UjTanarLicenc) -or [string]::IsNullOrWhiteSpace($UjDiakLicenc)) {
        Write-Host "Következő lépés: győződjön meg róla, hogy az A1 Plus tanári és diáklicencek rendelkezésre állnak, majd futtassa újra ezt a programot."
    }
    else {
        Write-Host "Következő lépés: cserélje le az A1 licenceket végleges A1 Plus licencekre a https://sulikon.freshdesk.com/a/solutions/articles/62000150184 cikk lépéseit követve."
    }
}
else {
    if (($A1TanarVeglegesCount -gt 0) -and ($A1DiakVeglegesCount -gt 0)) {
        Write-Host "Lejáró, próbaverziós Office 365 A1 diák és tanár licencek használaton kívül: OK (végleges A1 licenceket használnak)" -ForegroundColor Green
    }
    else {
        Write-Host "Lejáró, próbaverziós Office 365 A1 diák és tanár licencek használaton kívül: OK" -ForegroundColor Green
    }
} 


Read-Host -Prompt "Üssön ENTER-t a kilépéshez!"