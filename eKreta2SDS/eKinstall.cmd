@echo off
echo Ne felejtsd el tanulmanyozni az UTMUTATO.txt-t!
echo .
echo A telepites soran nyomj, ahol lehet "A"-t, vagy ha az nincs "Y"-t. Jo sokszor kell. 
echo Nem csinalsz bajt vele, ha veletlenul masodszor is elinditod ezt a telepitot.
cd %~dp0
md log
md output
powershell -executionpolicy bypass ".\bin\eKinstall.ps1" 
pause Ellenorizd a kimenetet, masold ki a hibakat, ha voltak! Aztan nyomj meg egy gombot.