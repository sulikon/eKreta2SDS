# Copyright 2020 EURO ONE Számítástechnikai Zártkörűen Működő Részvénytársaság
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, 
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#


[CmdletBinding()]
Param (
    [Parameter()] # mandatory on production
    [string] $schoolid, #Clear or Change  default value le for production use!
    [Parameter()] # mandatory on production
    [string] $SchoolName, #Clear or Change  default value le for production use!
    [Parameter()] # mandatory on production
    [string] $SchoolAddress, #Clear or Change  default value le for production use!
    [Parameter()] # mandatory on production
    [string] $Input_tanulok = '.\input\Tanulok_tantargyai_es_pedagogusai.xlsx', # the default parameters for input files. Clear or Change  default value le for production use!
    [Parameter()] 
    [string] $Input_gondviselok = "", # the default parameters for input files. Clear or Change  default value le for production use!
    [Parameter()][string]$UPNSuffix = "" , # the default parameters for input files. Clear or Change  default value le for production use! # mandatory on production
    [Parameter()][string]$StudentYear = "201920", # mandatory on production
    [Parameter()][string]$OutputPath = ".\output",
    [Parameter()][string]$LogPath = ".\log" ,
    [Parameter()][string]$SDSFolder = "",
    [Parameter()][string]$DomainName = "", # If domain name exists, it means On Prem AD + AD connect usage!
    [Parameter()][String]$TenantID = "", #for AzureAD connect, the tenantid is the ONMicrosoft domain nam of tenant.
    [Parameter()][String]$LogLevel = "Debug",
    [Parameter()][string]$PasswordPrefix = "PwdPrefix",
    [Parameter()][string]$OUNameTeachers = "", # sample  "OU=TeacherOU,DC=lego,DC=local"
    [Parameter()][string]$OUNameStudents = "", # sample  "OU=StudentOU,DC=lego,DC=local"
    [Parameter()][string]$NonTrustedADDomainDC, # If there any DC, then we auhenticate against this DC
    [switch]$SkipeKretaConvert = $false , #don't process the convert parts
    [switch]$newCred = $false, # Force request New Credential
    [Parameter()][switch]$FlipFirstnameLastname =  $false # reverse display name if $true
    )

if ($loglevel -match "TRANSCRIPT") {
    Start-transcript "$LogPath\eKreta2SDS-Transcript-$LogDate.Log"
}

$OutputCSVDelimiter = ","
$InputCSVDelimiter = ";"

# Check prereq
try {
    import-module PSFramework -NoClobber -ErrorAction Stop
    import-module AzureAd -NoClobber -ErrorAction Stop
    if ($DomainName -ne "") {
        Import-Module ActiveDirectory -NoClobber -ErrorAction Stop
    }
}
catch {
    write-host "Critical Error, unable to import all necessary Module"
    exit
}

#  Versioning 
$version = "20200331.1"

#Determine $PSR Script Root path
if ($null -ne $psISE) {
    $PSR = Split-Path -Path $psISE.CurrentFile.FullPath        
}
else {
    $PSR = $PSScriptRoot
}
if ($OutputPath -eq ".") {
    $OutputPath = Get-Location 
}
if ($LogPath -eq ".\log") {
    $LogPath = Join-Path (Get-Location) "log"
}
$LogDate = "$($(get-date).Year)" + $(get-date).month.ToString("00") + $(get-date).Day.ToString("00") + "-" + $(get-date).Hour.ToString("00") + $(get-date).minute.ToString("00")
Set-PSFLoggingProvider -Name 'LogFile' -FilePath "$LogPath\eKretaLaunch-$LogDate.Log" -Enabled $true
Write-PSFMessage -level Host -Message "eKretaLaunch Script started. Version:$Version. Logpath: $LogPath"  

if ($DomainName) 
{
    Write-PSFMessage -level Host -Message "Running mode: Local AD + Azure Active Directory"
}
else
{
    Write-PSFMessage -level Host -Message "Running mode: Only Azure Active Directory"
}

###########################################
# Export-AESKey
###########################################
Function Export-AESKey($AESKeyFilePath) {
    # Generate a random AES Encryption Key.
    $AESKey = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
	
    # Store the AESKey into a file. This file should be protected!  (e.g. ACL on the file to allow only select people to read)
    Set-Content $AESKeyFilePath $AESKey   # Any existing AES Key file will be overwritten		

} # end function Export-AESKey

###########################################
# Get-AESKey
###########################################
Function Get-AESKey($AESKeyFilePath) {
    write-host "GET AESKEY $AESKeyFilePath "
    if (!(Test-Path -Path $AESKeyFilePath -PathType Leaf)) {
        write-debug  "export AESKEY"
        Export-AESKey ($AESKeyFilePath)
    }
    Get-Content $AESKeyFilePath

} # end fucntion Get-AESKey

###########################################
# Export-Credential
# Usage: Export-Credential $CredentialObject $FileToSaveTo
###########################################
function Export-Credential($cred, $path) {
    $cred = $cred | Select-Object *
    $cred.password = $cred.Password | ConvertFrom-SecureString -key $key[1..16]
    #$cred | Export-Clixml $path
    Export-Clixml -inputobject $cred -path $path -Force
} # // end-function 

###########################################
# Get-MyCredential
###########################################
function Get-MyCredential([STRING] $CredPath, [Boolean] $newCred = $FALSE) {
    if ($newCred -or !(Test-Path -Path $CredPath -PathType Leaf)) { 
        Export-Credential (Get-Credential) $CredPath
    }
    $cred = Import-Clixml $CredPath
    
    try {
        $credPassword = $cred.Password | ConvertTo-SecureString -key $key[1..16]
    }
    catch {
        write-warning "Invalid AES Key, stored credential" 
        break;
    }
    
    $Credential = New-Object System.Management.Automation.PsCredential($cred.UserName, $credPassword)
    Return $Credential
}
# // end-function # Get-MyCredential



$global:azureadusers = @{ }
#create hash table from AD users!
function InitADUsers {
    try {
        Write-PSFMessage "Connect to azure ad: $tenantID"
        try {
            $AzureAdConnected = $null -ne (Get-AzureAddomain -erroraction SilentlyContinue | ? { $_.Name -EQ $TenantID })
        }
        Catch {
            $AzureAdConnected = $false
        }

        if ($AzureAdConnected -and !$AzureADCredential) {
            $d = [string] $(get-azureaddomain).name
            write-PSFMessage -level host "Already connected: $d"
        }
        else {
            #$AzureCredential = Get-Credential #temporary solution TODO
            if ($AzureCredential) {
                #Doesn't works with MFA!!!!
                $null = Connect-AzureAD -tenantID $tenantID -ErrorAction STOP -Credential $AzureCredential
            }
            else {
                Write-PSFMessage -level host "Azure AD kapcsolat. Várakozás a bejelentkezésre. A login ablak megjelenhet a háttérben is!"
                $null = Connect-AzureAD -tenantID $tenantID -ErrorAction STOP
            }
        }
        
    }
    catch {
        Write-PSFMessage -level Host "Unable to Connect or retrieve users from AzureAD!" -ErrorRecord $_
        exit
    }
}


function CreateADusers {
    [CMdletBinding()]
    PARAM
    ([Parameter()][String]$InputCSV = "",
        [Parameter()][String]$OUName = ""
    )

    # Import active directory module for running AD cmdlets
    #Store the data from ADUsers.csv in the $ADUsers variable
    $ADUsers = Import-csv $InputCSV


    #Loop through each row containing user details in the CSV file 
    foreach ($User in $ADUsers) {
        #Read user data from each field in each row and assign the data to a variable as below
		
        if ($User.Username -Match ("@")) {
            $SAMUsername = ($User.username.split("@"))[0]
            $SAMUsername = $SAMUsername.substring(0, [math]::min($SAMUsername.length, 20))
        }
        else {
            #NO USERNAME
        }
        $Username = $User.username
        $Password = $User.password
        $Firstname = $User.'first name'
        $Lastname = $User.'last name'
        $SISID = $user.'SIS ID'
        #Check to see if the user already exists in AD
        $aduser = Get-MyAdUser $SAMUsername
        if ($aduser) {            
            #If user does exist, give a warning
            Write-PSFMessage -level Warning "A user account with username $Username already exist in Active Directory."
        }
        else {
            #User does not exist then proceed to create the new user account
		
            #Account will be created in the OU provided by the $OU variable read from the CSV file
            
            $userpass = (convertto-securestring $Password -AsPlainText -Force)
            Write-PSFMessage -level host "Create User: $username"
            try {
                if ($loglevel -match "DEBUG") {
                    write-PSFMessage  "New-ADUser -SamAccountName $SAMUsername -UserPrincipalName ""$Username"" -Name ""$Firstname $Lastname"" -AccountPassword ""$userpass"" -Enabled $True -DisplayName ""$Lastname $Firstname"" -Path $OUName -EmployeeID $SISID   -ChangePasswordAtLogon $False"
                }                
                if ( $NonTrustedADDomainDC ) {
                    New-ADUser  -server $NonTrustedADDomainDC -credential $adcred -SamAccountName $SAMUsername -UserPrincipalName "$Username" -Name "$Firstname $Lastname" -AccountPassword $userpass -Enabled $True -DisplayName "$Lastname $Firstname" -Path $OUName -EmployeeID $SISID   -ChangePasswordAtLogon $False                                                            
                }
                else {
                    New-ADUser  -SamAccountName $SAMUsername -UserPrincipalName "$Username" -Name "$Firstname $Lastname" -AccountPassword $userpass -Enabled $True -DisplayName "$Lastname $Firstname" -Path $OUName -EmployeeID $SISID   -ChangePasswordAtLogon $False                
                }

                if ($?) {
                    $newuser = get-MyAduser $SAMUsername
                    Write-PSFMessage -level host "User created: $newuser.UserPrincipalName, SAM:$($newuser.SAMAccountname)"     
                }

            }
            catch {
                Write-PSFMessage -level critical "User creation error for user: $username"
            }
            finally {
            }
            
        }
    }
}


function Get-MyADUser {
    [CMdletBinding()]
    PARAM
    ([Parameter()][String]$UserName # SAMUsername
    )
    
    if ($username) {
        if ($NonTrustedADDomainDC) {
            $aduser = Get-ADUser -Server $NonTrustedADDomainDC -credential $adcred  -F { SamAccountName -eq $Username }                        # for nontrusted domain access
        }
        else {
            $aduser = Get-ADUser -F { SamAccountName -eq $Username }            
        }
    }
    return $aduser
}


function CheckAzureADUser {
    [CMdletBinding()]
    PARAM
    ([Parameter()][String]$UserName
    )
    if ($username) {
        if ($loglevel -match "DEBUG") {
            Write-PSFMessage "Check AzureADuser $username"
        }
        try {
            $User = Get-AzureADUser -ObjectID $Username -erroraction SilentlyContinue #UPN Name!    If user doesn't exists, it throw an exception!
        }
        Catch {
            $User = $null
        }
        if ($loglevel -match "DEBUG") {
            Write-PSFMessage "AzureADuser Checked: user existence:  $($null -ne $user)"
        }
    }
    return $user
}

function CallConvert {
    return  eKreta2Convert "$SchoolID" "$SchoolName" "$SchoolAddress" "$Input_tanulok" -UPNSuffix "$UPNSuffix" -tenantID "$tenantID" -PasswordPrefix $PasswordPrefix -AzureCredential $AzureCredential -DomainName $DomainName -StudentYear $StudentYear -outputPath $outputpath -LogPath $logpath -FlipFirstnameLastname:$FlipFirstnameLastname
    #reset the  LOG destination to the launcher!
    Set-PSFLoggingProvider -Name 'LogFile' -FilePath "$LogPath\eKretaLaunch-$LogDate.Log" -Enabled $true
}

##########################################
#  START MAIN
##########################################

##########################################
#  Get Credential
##########################################
try {
    $key = Get-AESKey(join-path (Get-Location) "aes.key")
    $credpath = (join-path (Get-Location) "mycred.key")
    $cred = Get-MyCredential $credpath $newCred
    write-PSFMessage "Got new credential $($cred.username)"
   
}
Catch {
    write-PSFMessage -level host "Kérem, adja meg az érvényes hitelesítő adatokat az Azure AD tenanthoz!" 
    return;
}
#$username = $cred.UserName
#$password = $cred.GetNetworkCredential().Password
$AzureCredential = $cred
InitAdUsers

try {
    $localADStudents = "LocalADStudent.csv"
    $LocalADTeachers = "LocalADTeacher.csv"

    try {
        import-module .\bin\eKreta2SDS.psm1
    }
    catch {
        write-host "Critical Error, unable to import all necessary Module"
        exit
    }
    
    
    if (!$SkipeKretaConvert) {
        $eKretaResult = CallConvert 
    }
    if ((test-path "$outputPath\$localADStudents") -or ((test-path "$outputPath\$LocalADTeachers"))) {
        
        # Write-host "ADmin account for Domain"
        Write-PSFMessage "Start Create Teachers Local AD Account"
        if ($NonTrustedADDomainDC) {
            $adcred = get-credential -Message "Admin for $NonTrustedADDomainDC"
        }

        if (test-path "$outputPath\$LocalADTeachers" ) {
            CreateADusers  "$outputPath\$LocalADTeachers" $OUNameTeachers
            $tc = import-csv "$outputPath\$localADTeachers" -Delimiter $OutputCSVDelimiter #this is from SDS output, with outputdelimiter
        }
        Write-PSFMessage "Start Create Students Local AD Account"
        if (test-path "$outputPath\$localADStudents" ) {
            CreateADusers  "$outputPath\$localADStudents" $OUNameStudents
            $St = import-csv "$outputPath\$localADStudents" -Delimiter $OutputCSVDelimiter #this is from SDS output, with outputdelimiter
        }
        Write-PSFMessage "Finish Create Students Local AD Account"

    }   
    else {
#        write-host "Local AD CSV files not found." # commented out to reduce complexity using AAD only mode
    }
    
    # Wait for sync
    # TODO push ADconnect sync
    $ad = $st + $tc
       
    $maxwaittime = 3600 # Loop
    $waittime = 5 # seconds between check iterations
    $totalusers = $ad.count
    $waitusers = $totalusers
    $loopcount = 0
    do {
        $ad | % {              
            $username = $_.username
            $user = CheckAzureADUser $username
            if (!$user) {
                #"WAit for user"
            }
            else {
                Write-psfmessage "User found in Azuread $username"
                $_.username = ""
                $waitusers = $waitusers - 1  
            }
        }
        if ($waitusers -gt 0) {
            write-host "Várakozás  $waitusers felhasználó létrehozására összesen $totalusers felhasználóból.   Próbálkozások száma: $loopcount  / $($maxwaittime / $waittime) iteration. Billenytűleütésre megáll."
            Start-Sleep -Seconds $waittime
        }
        # waiting until : key pressed or reach max wait time or  no more missing user
    } While ( !$Host.UI.RawUI.KeyAvailable -and ($loopcount++ -lt ($maxwaittime / $waittime) -and ($waitusers -gt 0)))
    if (($totalusers -gt 0 )) {
        # There were missig AD users. Repeat the conversions to fill the output csv-s with the missing users.
        write-psfmessage "$totalusers local AD users managed, repeat eKreta2Convert"
        if (!$SkipeKretaConvert) {
            $eKretaResult = CallConvert 
        }
    }
       
    # Copy exported files to target 
        
    if (![string]::IsNullOrEmpty($SDSFolder) ) {
        # Test-Path doesn't accept empty string!
        if (test-path $SDSFolder) {  
            Start-slepp -seconds 5
            copy-item "$outputpath\school.csv"  $SDSFolder
            copy-item "$outputpath\teacher.csv"  $SDSFolder
            copy-item "$outputpath\student.csv"  $SDSFolder
            copy-item "$outputpath\section.csv"  $SDSFolder
            copy-item "$outputpath\TeacherRoster.csv"  $SDSFolder
            copy-item "$outputpath\StudentEnrollment.csv"  $SDSFolder
            copy-item "$outputpath\user.csv"  $SDSFolder
            copy-item "$outputpath\GuardianRelationShip.csv"  $SDSFolder

            Write-PSFMessage "Converted data copied to target"
        } 
    }
} 
catch {
    $Exception = $_.Exception
    Write-PSFMessage -Level Critical "eKreta2Launch Error in Line:  $($Exception.ErrorRecord.Invocationinfo.ScriptLineNumber)"  -ErrorRecord $_ 
    if ($Loglevel -match "DEBUG") {
        Write-PSFMessage -Level Debug "eKreta2Launch Error    $($Exception.ErrorRecord)"
        Write-PSFMessage -Level Debug "eKreta2Launch Error  Stack  $($Exception.ErrorRecord.ScriptStackTrace) "
    }    
}
Finally {
    Write-PSFMessage -level Host "eKretaLaunch Script Finished." 
    if ($loglevel -match "TRANSCRIPT") {
        Stop-transcript "$LogPath\eKretaLaunch-Transcript-$LogDate.Log"
    }
}
