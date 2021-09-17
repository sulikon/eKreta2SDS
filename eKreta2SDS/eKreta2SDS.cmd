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

rem --- Ez alatt a vonal alatt nem sz�ks�ges m�dos�tani a 2020/21 tan�vben ---

rem Tan�v, most nem kell szerkeszteni
set param6=-StudentYear 202021
rem Napl�z�s szintje, most nem kell szerkeszteni
set param8=-LogLevel "Debug"

rem Vezet�kn�v �s keresztn�v ford�tott kezel�se (Csak akkor haszn�ljuk, ha magyar nevez�ktan szerint kell k�pezni a Displayname �rt�ket)
rem $true �rt�kn�l ford�tott nevez�ktan
set param9=-FlipFirstnameLastname:$true

rem T�bbiskol�s k�rnyezetekben c�lszer� lehet az egyes iskol�k csoportjainak megk�l�nb�ztet�se.
rem Itt adhat� meg az az el�tag, amivel minden csoport neve kezd�dik - ha meg van adva.
rem set param10=-SchoolSectionPrefix "Pr�bav�r"

rem T�bbiskol�s k�rnyezetekben c�lszer� lehet az egyes iskol�k csoportjainak megk�l�nb�ztet�se.
rem Itt adhat� meg az az ut�tag, amivel minden csoport neve v�gz�dik a tan�v jelz�se el�tt - ha meg van adva.
rem set param11=-SchoolSectionSuffix "Pr�bav�r"


rem Windows Credential Manager-ben l�trehozott Credential neve, ha nincs megadva, akkor minden fur�sn�l be kell jelentkezni
rem set param12=-AzureADCredential "eKreta2SDS-"

rem AzureAD-ban regisztr�lt alkalmaz�s azonos�t�ja GRAPH API-hoz. Ha nincs megadva, akkor nem lesz Graph Api haszn�lva.
rem set param13=-AppId "123456"

rem APP Kulcs GRAPH API-hoz. Ha nincs megadva, akkor nem lesz Graph Api haszn�lva.
rem set param14=-AppSecret "123456"

echo Ugye nem felejtetted el tanulmanyozni az UTMUTATO.txt-t?
echo .
cd %~dp0
powershell -executionpolicy bypass ".\bin\eKretaLaunch.ps1" %param1% %param2% %param3% %param4% %param5% %param6% %param7% %param8% %param9% %param10% %param11% %param12% %param13% %param14%
pause Ellenorizd a kimenetet, masold ki a hibakat, ha voltak! Aztan nyomj meg egy gombot. Reszletes naplok a TraceLog mappaban vannak.
