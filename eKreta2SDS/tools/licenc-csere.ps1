# Tömeges licenc-csere eszköz Office 365 oktatási változathoz
# Az alábbi script valamennyi felhasználón az Office 365 A1 for faculty licencet lecseréli Office 365 A1 Plus for faculty licencre, 
# továbbá valamennyi felhasználón az Office 365 A1 for students licencet lecseréli Office 365 A1 Plus for students licencre.
#
# Előfeltételek
#
# 1) Rendszergazdaként futtatott PowerShellből:
Install-Module MSOnline -Scope CurrentUser
#
# 2) Az Office 365 A1 Plus for faculty és Office 365 A1 Plus for students licencek látsszanak a környezetben. 
#
# 3) A tanárok Office 365 A1 for faculty, a diákok Office 365 A1 for students licenceket használjanak jelenleg. 
#
# Használat
#
# A scriptet powershellből le kell futtatni. Nem kérdez, cselekszik.
#

# bejelentkezés
$cred = Get-Credential
Connect-MsolService -Credential $cred

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
    [array]$diakok = $users | Where-Object {($_.isLicensed -eq $true) -and ($_.Licenses.AccountSKUID -eq $RegiDiakLicenc)} 
    Write-Host "Érintett diákok száma: $($diakok.Count)"
    $diakok | Set-MsolUserLicense –AddLicenses $UjDiakLicenc –RemoveLicenses $RegiDiakLicenc 
    # lecseréljük a tanári licenceket
    [array]$tanarok = $users | Where-Object {($_.isLicensed -eq $true) -and ($_.Licenses.AccountSKUID -eq $RegiTanarLicenc)}
    Write-Host "Érintett tanárok száma: $($tanarok.Count)"
    $tanarok | Set-MsolUserLicense –AddLicenses $UjTanarLicenc –RemoveLicenses $RegiTanarLicenc
}
Read-Host "Enter leütésére kilép"
# örülünk.
