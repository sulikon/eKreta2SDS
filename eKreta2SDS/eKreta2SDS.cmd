@echo off
rem --- K�rem, m�dos�tsa a megadott p�ldaadatokat az iskola adataira! ---

rem Az iskola oktat�si azonos�t�ja:
set param1=-schoolid '012345' 

rem Az iskola neve. �KEZETET NE haszn�ljon! Ez nem l�tszik a felhaszn�l�knak.
set param2=-SchoolName 'Probavari Altalanos Iskola' 

rem Az iskola c�me. �KEZETET NE haszn�ljon! Ez nem l�tszik a felhaszn�l�knak.
set param3=-SchoolAddress '4500 Probavar Kossuth u. 26.' 

rem Az Office 365 k�rnyezet domain neve
set param4=-UPNSuffix 'probavarsuli.hu'
set param5=-tenantid probavarsuli.hu

rem Felhaszn�l�k kezd� jelszav�nak eleje Legyen legal�bb 4 bet�, kisbet�t, nagybet�t �s egy jelet is tartalmazzon. 
rem A kezd� jelsz�ba az itt megadott prefix ut�n a felhaszn�l� saj�t oktat�si azonos�t�j�nak utols� 4 sz�mjegye ker�l.
set param7=-PasswordPrefix 'KL.Bp' 

rem --- Ez alatt a vonal alatt nem kell m�dos�tani a 2019/20 tan�vben ---

rem Tan�v, most nem kell szerkeszteni
set param6=-StudentYear 201920
rem Napl�z�s szintje, most nem kell szerkeszteni
set param8=-LogLevel "Debug"

rem Vezet�kn�v �s keresztn�v ford�tott kezel�se (Csak akkor haszn�ljuk, ha magyar nevez�ktan szerint kell k�pezni a Displayname �rt�ket)
rem $true �rt�kn�l ford�tott nevez�ktan
set param9=-FlipFirstnameLastname:$false

rem Windows Credential Manager-ben l�trehozott Credential neve, ha nincs megadva, akkor minden fur�sn�l be kell jelentkezni
rem set param10=-AzureADCredential "eKreta2SDS-"

echo Ugye nem felejtetted el tanulmanyozni az UTMUTATO.txt-t?
echo .
cd %~dp0
powershell -executionpolicy bypass ".\bin\eKretaLaunch.ps1" %param1% %param2% %param3% %param4% %param5% %param6% %param7% %param8% %param9%
pause Ellenorizd a kimenetet, masold ki a hibakat, ha voltak! Aztan nyomj meg egy gombot. Reszletes naplok a log mappaban vannak.
