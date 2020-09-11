# Eszköz egy környezetben minden felhasználó "festési" állapotának lekérdezéséhez.
# Szakszerűbben: azt az "AnchorId" tulajdonságot listázza ki minden felhasználóra, ami alapján a School Data Sync beazonosítja a tanárokat/diákokat.
# Az eredményt a képernyőre írja és elmenti AnchorId.csv néven is.
#
# Használat
#
# A scriptet powershellből le kell futtatni. Nem kérdez, cselekszik.
#

If ( [Environment]::Is64BitProcess ) {


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# telepítés
Install-Module AzureAD -Scope CurrentUser

# bejelentkezés
$null = Connect-AzureAD -ErrorAction Stop

Write-Host "AnchorId-k lekérdezése"
Write-Host "A tanároké 'Teacher_#', a diákoké 'Student_#' alakú, ahol # az oktatási azonosítót jelöli.

$users = Get-AzureADUser -All $true
$anchorinfo = @()

$users | % {  $anchor=($_.ExtensionProperty)."extension_fe2174665583431c953114ff7268b7b3_Education_AnchorId";  Write-Host "$($_.userprincipalname);$($anchor)"; $anchorinfo += @([pscustomobject]@{'UserPrincipalName' = $_.userprincipalname; AnchorID = $anchor }) }
$anchorinfo | export-csv ".\AnchorId.csv" -delimiter ";" -Encoding UTF8 -NoTypeInformation

Read-Host "Enter leütésére kilép"
# örülünk.
}
else {
    Write-Host "Hiba: a futtatás 32 bites Windowson vagy 32 bites programból indítva nem támogatott" -ForegroundColor Red
    Read-Host "Enterre kilép."
}