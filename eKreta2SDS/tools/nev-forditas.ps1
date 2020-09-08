# School Data Sync által létrehozott, fordított DisplayName-ek javítása Vezetéknév Keresztnév formára
# Használat
#
# A scriptet powershellből le kell futtatni. Nem kérdez, cselekszik.
#

If ( [Environment]::Is64BitProcess ) {

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Install-Module AzureAD -Scope CurrentUser

# bejelentkezés
$cred = Get-Credential
Connect-AzureAD -Credential $cred

# lekérdezünk minden felhasználót
[array]$users = Get-AzureADUser -All $true 

# lecseréljük a displayname-eket "Surname Givenname" formátumúra az SDS által kezelt felhasználókon
$users | Where-Object { $_.ExtensionProperty.extension_fe2174665583431c953114ff7268b7b3_Education_SyncSource -eq "SIS" } | ForEach-Object { Set-AzureADUser -ObjectId $_.objectid -DisplayName "$($_.surname) $($_.givenname)" }
# örülünk.
}
else {
    Write-Host "Hiba: a futtatás 32 bites Windowson vagy 32 bites programból indítva nem támogatott" -ForegroundColor Red
    Read-Host "Enterre kilép."
}