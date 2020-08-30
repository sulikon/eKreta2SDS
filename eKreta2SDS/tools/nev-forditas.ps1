# School Data Sync által létrehozott, fordított DisplayName-ek javítása Vezetéknév Keresztnév formára

# Előfeltételek
#
Install-Module AzureAD -Scope CurrentUser
#
#
# Használat
#
# A scriptet powershellből le kell futtatni. Nem kérdez, cselekszik.
#

# bejelentkezés
$cred = Get-Credential
Connect-AzureAD -Credential $cred

# lekérdezünk minden felhasználót
[array]$users = Get-AzureADUser -All $true 

# lecseréljük a displayname-eket "Surname Givenname" formátumúra az SDS által kezelt felhasználókon
$users | Where-Object { $_.ExtensionProperty.extension_fe2174665583431c953114ff7268b7b3_Education_SyncSource -eq "SIS" } | ForEach-Object { Set-AzureADUser -ObjectId $_.objectid -DisplayName "$($_.surname) $($_.givenname)" }
# örülünk.
