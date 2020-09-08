# Tömeges licenc-csere eszköz Office 365 oktatási változathoz
# Az alábbi script valamennyi felhasználón az Office 365 A1 for faculty licencet lecseréli Office 365 A1 Plus for faculty licencre, 
# továbbá valamennyi felhasználón az Office 365 A1 for students licencet lecseréli Office 365 A1 Plus for students licencre.
#
# Előfeltételek
#
# 1) Az Office 365 A1 Plus for faculty és Office 365 A1 Plus for students licencek látsszanak a környezetben. 
#
# 2) A tanárok Office 365 A1 for faculty, a diákok Office 365 A1 for students licenceket használjanak jelenleg. 
#
# Használat
#
# A scriptet powershellből le kell futtatni. Nem kérdez, cselekszik.
#
If ( [Environment]::Is64BitProcess ) {

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# telepítés
Install-Module MSOnline -Scope CurrentUser

# bejelentkezés
$null = Connect-MsolService -ErrorAction Stop

# licencek lekérdezése
[array]$licencek = Get-MsolAccountSku

# A1 és A1 Plus diák és tanári licencek azonosítójának lekérdezése
$RegiDiakLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_STUDENT" } | Select-Object -First 1).AccountSkuId
$UjDiakLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_IW_STUDENT" } | Select-Object -First 1).AccountSkuId
$RegiTanarLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_FACULTY" } | Select-Object -First 1).AccountSkuId
$UjTanarLicenc = ($licencek | Where-Object { $_.AccountSkuId -match "STANDARDWOFFPACK_IW_FACULTY" } | Select-Object -First 1).AccountSkuId

# Ellenőrizzük, sikeres volt-e a lekérdezés
if ([string]::IsNullOrWhiteSpace($RegiDiakLicenc) -or [string]::IsNullOrWhiteSpace($UjDiakLicenc) -or [string]::IsNullOrWhiteSpace($RegiTanarLicenc) -or [string]::IsNullOrWhiteSpace($UjTanarLicenc)) {
    # megállunk hibával
    throw Write-Host "Nem sikerült azonosítani a licenceket!"
}
else {
    # cseréljük a licenceket
    Write-Host "Licencek cseréje"
    # lekérdezünk minden felhasználót 
    [array]$users = Get-MsolUser -All 

    # lecseréljük a diáklicenceket
    [array]$diakokcs = $users | Where-Object {($_.isLicensed -eq $true) -and ($_.Licenses.AccountSKUID -eq $RegiDiakLicenc) -and !($_.Licenses.AccountSKUID -contains $UjDiakLicenc)} 
    Write-Host "A1 licencű diákok száma: $($diakokcs.Count)" -ForegroundColor Green
    if ($diakokcs.Count -gt 0) {
        write-host "Cserélünk A1 Plus-ra" -ForegroundColor Green
        $diakokcs | % { $_.UserPrincipalName;Set-MsolUserLicense -ObjectId $_.objectid –AddLicenses $UjDiakLicenc –RemoveLicenses $RegiDiakLicenc}
    }
    # töröljük a régi diáklicenceket
    [array]$diakokt = $users | Where-Object {($_.isLicensed -eq $true) -and ($_.Licenses.AccountSKUID -eq $RegiDiakLicenc) -and ($_.Licenses.AccountSKUID -eq $UjDiakLicenc)} 
    Write-Host "A1 és A1 Plus licencű diákok száma: $($diakokt.Count)" -ForegroundColor Green
    if ($diakokt.Count -gt 0) {
        write-host "Az A1-et töröljük róluk, marad az A1 Plus" -ForegroundColor Green
        $diakokt | % { $_.UserPrincipalName;Set-MsolUserLicense -ObjectId $_.objectid –RemoveLicenses $RegiDiakLicenc}
    }
    # lecseréljük a tanári licenceket
    [array]$tanarokcs = $users | Where-Object {($_.isLicensed -eq $true) -and ($_.Licenses.AccountSKUID -eq $RegiTanarLicenc) -and !($_.Licenses.AccountSKUID -contains $UjTanarLicenc)} 
    Write-Host "A1 licencű tanárok száma: $($tanarokcs.Count)" -ForegroundColor Green
    if ($tanarokcs.Count -gt 0) {
        write-host "Cserélünk A1 Plus-ra" -ForegroundColor Green
        $tanarokcs | % { $_.UserPrincipalName;Set-MsolUserLicense -ObjectId $_.objectid –AddLicenses $UjTanarLicenc –RemoveLicenses $RegiTanarLicenc}
    }
    # töröljük a régi tanári licenceket
    [array]$tanarokt = $users | Where-Object {($_.isLicensed -eq $true) -and ($_.Licenses.AccountSKUID -eq $RegiTanarLicenc) -and ($_.Licenses.AccountSKUID -eq $UjTanarLicenc)} 
    Write-Host "A1 és A1 Plus licencű tanárok száma: $($tanarokt.Count)" -ForegroundColor Green
    if ($tanarokt.Count -gt 0) {
        write-host "Az A1-et töröljük róluk, marad az A1 Plus" -ForegroundColor Green
        $tanarokt | % { $_.UserPrincipalName;Set-MsolUserLicense -ObjectId $_.objectid –RemoveLicenses $RegiTanarLicenc}
    }
}
Read-Host "Enter leütésére kilép"
# örülünk.
}
else {
    Write-Host "Hiba: a futtatás 32 bites Windowson vagy 32 bites programból indítva nem támogatott" -ForegroundColor Red
    Read-Host "Enterre kilép."
}