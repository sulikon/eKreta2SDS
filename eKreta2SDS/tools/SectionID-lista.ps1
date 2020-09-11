# Ez az eszköz arra használható, hogy megnézzük: milyen SectionID-jú csoportok léteznek a rendszerben.
# Kilistáz minden Azure AD csoportot és a Section_ kezdetű mailNickName-űekről levágja a "Section_" szöveget és növekvő sorrendben kiírja őket.
#
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

Write-Host "SectionId-k lekérdezése"

Get-AzureADGroup -All $true | Select-Object -Property mailnickname | Where-Object { $_.mailnickname -match "Section_"}  | % {  $_.mailnickname.substring(8)} | Sort-Object

Read-Host "Enter leütésére kilép"
# örülünk.
}
else {
    Write-Host "Hiba: a futtatás 32 bites Windowson vagy 32 bites programból indítva nem támogatott" -ForegroundColor Red
    Read-Host "Enterre kilép."
}
