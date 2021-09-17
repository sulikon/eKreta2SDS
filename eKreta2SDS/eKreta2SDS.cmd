@echo off
rem --- Kérem, módosítsa a megadott példaadatokat az iskola adataira! ---

rem Az iskola oktatási azonosítója:
set param1=-schoolid '012345' 

rem Az iskola neve. ÉKEZETET NE használjon! Ez nem látszik a felhasználóknak.
set param2=-SchoolName 'Probavari Altalanos Iskola' 

rem Az iskola címe. ÉKEZETET NE használjon! Ez nem látszik a felhasználóknak.
set param3=-SchoolAddress '4500 Probavar Kossuth u. 26.' 

rem Az Office 365 környezet domain neve
set param4=-UPNSuffix 'probavarsuli.hu'
set param5=-tenantid probavarsuli.hu

rem Felhasználók kezdõ jelszavának eleje Legyen legalább 4 betû, kisbetût, nagybetût és egy jelet is tartalmazzon. 
rem A kezdõ jelszóba az itt megadott prefix után a felhasználó saját oktatási azonosítójának utolsó 4 számjegye kerül.
set param7=-PasswordPrefix 'KL.Bp' 

rem --- Ez alatt a vonal alatt nem szükséges módosítani a 2020/21 tanévben ---

rem Tanév, most nem kell szerkeszteni
set param6=-StudentYear 202021
rem Naplózás szintje, most nem kell szerkeszteni
set param8=-LogLevel "Debug"

rem Vezetéknév és keresztnév fordított kezelése (Csak akkor használjuk, ha magyar nevezéktan szerint kell képezni a Displayname értéket)
rem $true értéknél fordított nevezéktan
set param9=-FlipFirstnameLastname:$true

rem Többiskolás környezetekben célszerû lehet az egyes iskolák csoportjainak megkülönböztetése.
rem Itt adható meg az az elõtag, amivel minden csoport neve kezdõdik - ha meg van adva.
rem set param10=-SchoolSectionPrefix "Próbavár"

rem Többiskolás környezetekben célszerû lehet az egyes iskolák csoportjainak megkülönböztetése.
rem Itt adható meg az az utótag, amivel minden csoport neve végzõdik a tanév jelzése elõtt - ha meg van adva.
rem set param11=-SchoolSectionSuffix "Próbavár"


rem Windows Credential Manager-ben létrehozott Credential neve, ha nincs megadva, akkor minden furásnál be kell jelentkezni
rem set param12=-AzureADCredential "eKreta2SDS-"

rem AzureAD-ban regisztrált alkalmazás azonosítója GRAPH API-hoz. Ha nincs megadva, akkor nem lesz Graph Api használva.
rem set param13=-AppId "123456"

rem APP Kulcs GRAPH API-hoz. Ha nincs megadva, akkor nem lesz Graph Api használva.
rem set param14=-AppSecret "123456"

echo Ugye nem felejtetted el tanulmanyozni az UTMUTATO.txt-t?
echo .
cd %~dp0
powershell -executionpolicy bypass ".\bin\eKretaLaunch.ps1" %param1% %param2% %param3% %param4% %param5% %param6% %param7% %param8% %param9% %param10% %param11% %param12% %param13% %param14%
pause Ellenorizd a kimenetet, masold ki a hibakat, ha voltak! Aztan nyomj meg egy gombot. Reszletes naplok a TraceLog mappaban vannak.
