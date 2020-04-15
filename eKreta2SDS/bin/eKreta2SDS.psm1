# Copyright 2020 EURO ONE Számítástechnikai Zártkörűen Működő Részvénytársaság
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, 
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


<# eKreta SIS transforms
 for ISE: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
        
 Requirements
   Powershell 5.1 
 Prerequisites:  install these with Amdinistrative rights!
       Install-PackageProvider Nuget -Trusted
       Register-PSRepository -Default 
       
    Join-Object: https://www.powershellgallery.com/packages/Join-Object/2.0.1
		Install-module Join-Object -Trusted -scope CurrentUser 
    PSExcel: https://www.powershellgallery.com/packages/PSExcel/1.0.2
		Install-module PSExcel -Trusted -scope CurrentUser 
    AzureAD: https://www.powershellgallery.com/packages/AzureAD/2.0.2.76
       Install-module AzureAd  -Trusted -scope CurrentUser 
    PSFramework: https://www.powershellgallery.com/packages/PSFramework/1.0.19
       Install-Module PSFramework -scope CurrentUser 
    Credential Manager:  https://www.powershellgallery.com/packages/CredentialManager/2.0
        Install-Module CredentialManager -scope CurrentUser

    For local AD mode:
      #  Install Active Directory Module Powershell. Require Administrator rights and UAC elevation
      Install by GUI (Add feature) or Powershell for W10 >=1809:
         Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
#>

# TODO
# Stored Azure Credential mgmt.


function Remove-StringDiacritic {
    <#
.SYNOPSIS
	This function will remove the diacritics (accents) characters from a string.
.DESCRIPTION
	This function will remove the diacritics (accents) characters from a string.
.PARAMETER String
	Specifies the String(s) on which the diacritics need to be removed
.PARAMETER NormalizationForm
	Specifies the normalization form to use
	https://msdn.microsoft.com/en-us/library/system.text.normalizationform(v=vs.110).aspx
.EXAMPLE
	PS C:\> Remove-StringDiacritic "L'été de Raphaël"
	L'ete de Raphael
.NOTES
	Francois-Xavier Cat
	@lazywinadmin
	lazywinadmin.com
	github.com/lazywinadmin
#>
    [CMdletBinding()]
    PARAM
    (
        [ValidateNotNullOrEmpty()]
        [Alias('Text')]
        [System.String[]]$String,
        [System.Text.NormalizationForm]$NormalizationForm = "FormD"
    )

    FOREACH ($StringValue in $String) {
        Write-Verbose -Message "$StringValue"
        try {
            # Normalize the String
            $Normalized = $StringValue.Normalize($NormalizationForm)
            $NewString = New-Object -TypeName System.Text.StringBuilder

            # Convert the String to CharArray
            $normalized.ToCharArray() |
            ForEach-Object -Process {
                if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($psitem) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
                    [void]$NewString.Append($psitem)
                }
            }

            #Combine the new string chars
            Write-Output $($NewString -as [string])
        }
        Catch {
            Write-Error -Message $Error[0].Exception.Message
        }
    }
}

#Hash table with overrides
#The OverrideType contains the type
#Key is the key, value is the value
# Known Overridetypes managed in CODE
#  Value: TeacherName: key: Teacher Fullname, value: Teacher Fullname
#  Value: TeacherName2Username:  key: on Teacher Fullname, value:TeacherUserName
#  Value: TeacherName2ID  : key: Teacher FullName, value: TeacherID
#  Value: TeacherID2ID: key: TeacherID, value: TeacherID
#  Value: StudentID2FirstName: key: Student ID, value: StudentFirstName
#  Value: StudentID2LastName: key: Student ID, value: StudentLastName


function InitOverride {
    try {
        Import-Csv $OverrideFile -Delimiter $InputCSVDelimiter | % { $Overridetable[$_.schoolid + ":" + $_.Type + ":" + $_.Key] = $_.Data }
        #for multiple column New-Object -Type PSCustomObject -Property @{'Value' = '$_.Data'}             
    }
    catch {
        Write-PSFMessage "Unable to initializeImport Override.csv!" -ErrorRecord $_
    }
}

Function Get-Override {
    Param ([string]$type, [string]$keyx, [string] $nonoverridedvalue)
    $overrided = $Overridetable[$schoolid + ":" + $type + ":" + $keyx]
    if (!$overrided) {
        if ($nonoverridedvalue) {
            return $nonoverridedvalue
        }
    }
    if ($loglevel -match "DEBUG") {
        Write-PSFMessage -level "Debug" "Override. Type:$type From:$keyx  To:$overrided"
    }
    Return $overrided
    
}

function InitAzureAD {
    try {
        Write-PSFMessage "Connect to azure ad: $tenantID"
        try {
            $AzureAdConnected = $null -ne (Get-AzureAddomain -erroraction SilentlyContinue | ? { $_.Name -EQ $TenantID })
        }
        Catch {
            $AzureAdConnected = $false
        }

        if ($AzureAdConnected) {
            write-PSFMessage "Already connected"
        }
        else {
            <##>if (!$tenantid ) {
                Write-PSFMessage -level host "Azure AD kapcsolat. Várakozás a bejelentkezésre. Login ablak megjelenhet a háttérben is!"
                $null = Connect-AzureAD -ErrorAction STOP
            }
            else {
                #>
                #$AzureCredential 
                if ($AzureCredential) {
                    #Doesn't works with MFA!!!!
                    $null = Connect-AzureAD -tenantID $tenantID -ErrorAction STOP -Credential $AzureCredential
                }
                else {
                    Write-PSFMessage -level host "Azure AD kapcsolat. Várakozás a bejelentkezésre. Login ablak megjelenhet a háttérben is!"
                    $null = Connect-AzureAD -tenantID $tenantID -ErrorAction STOP
                }
            }
        }
        #Create a Hash table with UPN and SIS ID
        #ALl: retrieve extended attributes also
        Write-PSFMessage -level host "Azure AD userek betöltése lekezdődik"
        $null = Get-AzureADUser  -all $true | % { 
            $userext = $_ | Select -ExpandProperty ExtensionProperty;
            switch ( $userext.extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType) {
                "Teacher" { $SID = $userext.extension_fe2174665583431c953114ff7268b7b3_Education_SyncSource_TeacherId }
                "Student" { $SID = $userext.extension_fe2174665583431c953114ff7268b7b3_Education_SyncSource_StudentId }
                default { $SID = "" }
            }; 
            If ($SID -match "^201920\d+") {      # detect pre-2020.03.31 generated SIDs to warn user to put them in override
                $global:oldgeneratedsid++
            }
            $global:azureadusers[$_.UserPrincipalName] = $SID
        }
        Write-PSFMessage -level host "Azure AD userek betöltése befejezödött: $($global:azureadusers.count) user account letöltődött."
        Write-PSFMessage -tag Report "Azure AD users retrieved from Azure: $($global:azureadusers.count)"            
        $global:AzureADGroups = Get-AzureADGroup -all $true 
        $Global:sid = 10000
        #retrieve all section groups and their SID. Determine the highest used Section SID in Azure AD (for new Section SIDs)
        $global:AzureADGroups | % {
          if ($_.MailNickName.Length -ge 8) {
              if ($_.MailNickName.Substring(0, 8) -eq "Section_") {
                  #Only for Section groups!
                  $SectionID = [int] $_.MailNickName.Substring(8)
                  $global:sections[$_.Displayname] = $SectionID
                  if ($Global:sid -le $SectionID) {
                      $Global:sid = $SectionID
                  }
              }
          }
        }
        # TODO:         
        #$azureadusers|foreach-object{$global:azureadusers[$_.UserPrincipalName] = "1"} 
        # Teacher SIS ID: extension_fe2174665583431c953114ff7268b7b3_Education_SyncSource_TeacherId
        # retrieve SIS ID: ($azureadusers[1]|Select -ExpandProperty ExtensionProperty).get_item("extension_fe2174665583431c953114ff7268b7b3_Education_SyncSource_TeacherId")
        # vagy ($user|Select -ExpandProperty ExtensionProperty).extension_fe2174665583431c953114ff7268b7b3_Education_SyncSource_TeacherId
    }
    catch {
        Write-PSFMessage -level Host "Unable to Connect or retrieve users from AzureAD!" -ErrorRecord $_
        exit
    }
}

# Username check and incrementally used new username
# DoN't check SID equality!
function OLD_DuplicatedUsernameCheck {
    param([string] $inputusername)
    $postfix = 1
    $outputusername = $inputusername
    while (($null -ne $global:usernames[$outputusername]) -or
        ($null -ne $global:azureadusers["$outputusername@$upnsuffix"])) {
        $outputusername = $inputusername + $postfix.ToString()
        $null = $postfix++
    }
    #we use a hash table, but not needed the value, so use a fix number 1 as value
    $global:usernames.add($outputusername, "1")
    return $outputusername
}


#Generate a new Section ID
function Get-SectionID {
    param (
        [string] $SectionName
    )

    if (!$SkipAzureADCheck) {
        return fSId #AUTO INCREMENTED UNIQUE SID
    }
    else {
        if ( $null -ne $global:Sections[$SectionName]) {
            # Sectionname already exists in AD. Use the existing Section ID!
            return $global:sections[$SectionName]
        }
        else {
            return fSId #AUTO INCREMENTED UNIQUE SID
        }
    }
}



#Végső SectionName meghatározása
function Get-SectionName {
    param (
        [string] $SectionName,
        [string] $ClassName
    )
    $StudentYearSectionSuffix = $StudentYear.Substring(2, 2) + "-" + $StudentYear.Substring(4, 2)
    $sn = $SectionName + $SectioNSeparator + $ClassName + $SectioNSeparator + $StudentYearSectionSuffix
    #Remove comma from Section Name 
    $sn = $sn -replace ","
    #Can change sectionname
    return Get-Override "SectionName" $sn $sn
}


#Check for duplicated user name. Return a new username if the user already exist!
# the usernames are in UPN name format!
# Return the same username if user and SID exist.
# Return with new username if user name conflict, but can resolve it
# return with empty string if can't resolve conflict
# For Local AD mode:
function Get-UniqueUsername {
    param([string] $inputusername,
        [string] $inputSID,
        [string] $inputName)    
    if (![string]::IsNullOrWhiteSpace($inputusername) -and ![string]::IsNullOrWhiteSpace($inputSID)) {   

        if (($global:azureadusers[$inputusername] -eq $InputSID) -or ($global:usernames[$inputusername] -eq $InputSID)) {
            #User already exist in new username table or AzureADtable with the same SID! 
            $newusername = $Inputusername
        }
        elseif (($null -ne $global:usernames[$Inputusername]) -or
            ($null -ne $global:azureadusers[$Inputusername])) {
            #Inputusername  conflict in AzureADTable or Usertable!
            # Generate newusername 
            # New username : username  + InputSID last 2 character + @UPN Suffix
            $newusername = $inputusername.split("@")[0] + $InputSID.Substring($InputSID.length - 2) + "@" + $inputusername.split("@")[1]
            Write-PSFMessage  "New username generated to resolve conflict: $InputUserName -> $newusername SID: $InputSID!" -tag "Report"
            
            if (($global:usernames[$newusername] -eq $InputSID) -or ($global:azureadusers[$newusername] -eq $InputSID)) {
                #newUser already exist in new username table or AzureADtable with the same SID!
                #everything is OK
            }
            elseif (($null -ne $global:usernames[$newusername]) -or ($null -ne $global:azureadusers[$newusername])) {
                #newusername still has conflict with existing usernames with different SID$
                Write-PSFMessage -level Important "User name conflict with suggested new name: $newusername. Manually resolving needed!" -tag "Report"
                $newusername = "" 
            }
            else {
                #New generated username hasn't conflict. 
                #Add to usernames array
                Write-PSFMessage -Verbose "User name conflict: $INputusername, $InputSID, New used username:$newusername"
                $global:usernames[$newusername] = $InputSID
            }
        }
        else {
            #No Conflict with inputusername
            #Add to usernames array
            $newusername = $Inputusername
            $global:usernames[$newusername] = $InputSID
        }      
    }
    else {
        Write-PSFMessage "$($inputName): hiányzó felhasználónév ($InputUsername) vagy oktatási azonosító ($InputSID). Gyors megoldás: vigye fel az override.csv-be az alábbi sort!" -Verbose
        throw Write-PSFMessage ("TeacherName2ID;" + $Schoolid + ";" + $inputName + ";" + (Get-Random -Minimum 1000000 -Maximum 9999999)) -Verbose
    }
    return $newusername
}
    
# Convert teacher name, drop special prefixes
function Convert-TeacherName {
    Param([string] $fullname)
    $newname = $fullname
    if (![string]::IsNullOrWhiteSpace($fullname)) {
        #can be empty input parameter!
        if ($fullname.Substring(0, 1) -eq "[") {               
            $newname = $newname -replace "^\[KA\s+[0-9]+]\s+Külsős\s+", ""
            $newname = $newname -replace "^\[KA\s+[0-9]+]\s+", "" # For Full names containing "[KA x]" without "Külsős"
            $newname = $newname -replace "^\[HO\s+[0-9]+]\s+", ""
            $newname = $newname -replace "^\[H.O.\]\s+Külsős\s+", ""
            $newname = $newname -replace "^\[H.O.\]\s+", "" # For Full names containing "[H.O. x]" without "Külsős"
            $newname = $newname -replace "^\[\.+\]\s+", ""
        }
    }
    return $newname
}

#Create username from fullname. Username is allways in UPN format!
# used for Teacher Name
function Get-Username {
    Param([string] $fullname, [string] $SID) #already overrided, cleaned names!
    #check override and return if found!
    $tUsername = get-override "TeacherID2UserName" $SID
    if (!$tUserName) {
        $tUsername = get-override "StudentID2UserName" $SID
    }
    
    if ($tUserName) {
        $newusername = $tUsername
    }
    elseif ($Naming -eq $Namingnodots) {
        #remove accents and any non word characters,  "-"  , but include space
        $newusername = ((Remove-StringDiacritic($fullname)) -replace '[^a-zA-Z_0-9\-]', '')
        $newusername = $newusername  -replace '\.\.+', '.' -replace '\.+$', '' -replace '^\.+', ''
    }
    elseif ($Naming -eq $Namingwithdots) {
        #  Full name with "." as separator
        #remove accents and any non word characters,  - space
        $parts = $((Remove-StringDiacritic($fullname)) -replace '[^a-zA-Z_0-9\-^\s]', '').Split(" ")
        $newusername = ($parts -join ".")     
        $newusername = $newusername  -replace '\.\.+', '.' -replace '\.+$', '' -replace '^\.+', ''
    }
    else {
        #Default User name generation!
        # Lastname and First chacterrs of other names
        #remove accents and any non word characters,  - space
        $parts = $((Remove-StringDiacritic($fullname)) -replace '[^a-zA-Z_0-9\-^\s]', '').Split(" ")
    
        #Algorithms:  firstname, max 10 char and the  First letters of other names
        $firstpart = $parts[0].substring(0, [math]::min($parts[0].length, 10))

        $newusername = $firstpart + (($parts[(1..($parts.count - 1))] | % { $_.Substring(0, 1) }) -join "")       ### potenciális substring hiba, túl rövid string esetén
        $newusername = $newusername  -replace '\.\.+', '.' -replace '\.+$', '' -replace '^\.+', ''
    }
    
    if (!($newusername -match "@")) {
        #Non UPN format yet!
        $newusername = $newusername + "@" + $upnsuffix
    }
           
    return $newusername
}

#Give back the Firstname from FullName
function get-UserFirstname {
    Param([string] $fullname, [switch]$FlipFirstnameLastname)
    #check override
    $userfullname = Get-OverRide "TeacherName" $fullname $fullname
    $parts = $userfullname.Split(" ")
    if ($FlipFirstnameLastname) {
        $fn = ($parts[0..($parts.count - 2)]) -join " "
    } else {
        $fn = $parts[$parts.count - 1]
    }
    Return $fn
}


#Give back the Lastname from FullName
# The lastnames is all names except Firstname!
function get-UserLastname {
    Param([string] $fullname, [switch]$FlipFirstnameLastname)
    #check override
    $userfullname = Get-OverRide "TeacherName" $fullname $fullname
    $parts = $userfullname.Split(" ")
    if ($FlipFirstnameLastname) {
        $ln = $parts[$parts.count - 1]
    } else {
        $ln = ($parts[0..($parts.count - 2)]) -join " "
    }
    
    Return $ln
}


function Generate-StudentPassword {
    param ([string] $ID)
    if (($id.Length -ge 4) -and ($SchoolId -ne $SchoolIdSopron )) {
        return "$PasswordPrefix$($ID.Substring($ID.length-4))"    
    }
    else {
        return "$PasswordPrefix"
    }
}


function Generate-TeacherPassword {
    param ([string] $ID)
    if (($id.Length -ge 4) -and ($SchoolId -ne $SchoolIdSopron )) {
        return "$PasswordPrefix$($ID.Substring($ID.length-4))"    
    }
    else {
        return "$PasswordPrefix"
    }
}

#Generate Teacher ID from TeacherID,TeacherName and  OverrideData
function Get-TeacherID {
    param ([string] $TName0,
        [string] $TID,
        [bool] $warn)
        
    #Get override
    $TID = Get-Override "TeacherName2ID" $Tname0 $TID
    # If username contanit [KA n, and no Override!    
    if (![string]::IsNullOrWhiteSpace($TName0)) {
        if (($TID.length -eq 0) -and ($TName0.substring(0, 1) -eq "[")) {              # faulty method replaced. Could generate same SIS ID for "KA 1" and "HO 1"
            $oldTID = $StudentYear + (($tname0 -replace "\].+", "") -replace ("^\" + $Tname0.Substring(0, 3) + "\s+"), "")             
            $TID = $StudentYear + ($tname0.Substring(1, $TName0.IndexOf("]") - 1 ) -replace "\s+", "")              
            if ($warn -and ($oldTID -ne (Get-Override "TeacherID2ID" $TID $TID))) {
                if ($Global:oldgeneratedsid -gt 0) {
                    Write-PSFMessage "2020.03.31-n megváltozott az oktatási azonosító nélküli tanárok azonosítógenerálása." -Verbose
                    Write-PSFMessage "Az új generálási szabály miatt új felhasználók jöhetnek létre a már meglévők mellé." -Verbose
                    Write-PSFMessage "Ez úgy kerülhető el, ha az input\override.csv-ben minden érintetthez felvisz egy sort." -Verbose
                    Write-PSFMessage "Ebben az output\teacher.csv-ben található új azonosítót a régire cseréljük vissza." -Verbose
                    Write-PSFMessage "Ezeket az új sorokat tegye az input\override.csv-be:"  -Verbose
                    $Global:oldgeneratedsid=0            
                }
                Write-PSFMessage "# $TName0 régi azonosítójának megtartása:"  -Verbose
                Write-PSFMessage "TeacherID2ID;$SchoolID;$TID;$oldTID"  -Verbose 
            }
        }
    }
    $TID = Get-Override "TeacherID2ID" $TID $TID
    return $TID
}

function fSId {
    $global:sid++    
    return $global:sid
}
   

##################################################
#eKreta2SDS funcion
##################################################
Function eKreta2Convert() {


    [CmdletBinding()]
    Param (
        [Parameter()] # mandatory on production
        [string] $schoolid,
        [Parameter()] # mandatory on production
        [string] $SchoolName, 
        [Parameter()] # mandatory on production
        [string] $SchoolAddress, 
        [Parameter()] # mandatory on production
        [string] $Input_tanulok, 
        [Parameter()] 
        [string] $Input_gondviselok ,
        [Parameter()][string]$StudentYear, # mandatory on production
        [Parameter()][string]$UPNSuffix, 
        [Parameter()][string]$InputPath = ".\input",
        [Parameter()][string]$OutputPath = ".\output",
        [Parameter()][string]$LogPath = ".\log",
        [Parameter()][string]$DomainName = "", # If domain name exists, it means On Prem AD + AD connect usage!
        [Parameter()][String]$TenantID, #for AzureAD connect, the tenanid is the ONMicrosoft domain nam of tenant.
        [Parameter()][String]$LogLevel = "",
        [Parameter()][switch]$AddUPNSuffix = $false, # exported files contain full UPN Names
        [Parameter()][switch]$SkipAzureADCheck = $false, # can be skipe the azure ad connection and check!
        [Parameter()][System.Management.Automation.PSCredential]$AzureCredential = [System.Management.Automation.PSCredential]::Empty,
        [Parameter()][string]$PasswordPrefix = "PwdPrefix",
        [Parameter()][switch]$FlipFirstnameLastname = $false
    )
    #  Versioning 
    $version = "20200415.2"

    # Check prereq
    try {
        import-module PSFramework -NoClobber -ErrorAction Stop
        import-module PSExcel -NoClobber -ErrorAction Stop
        import-module Join-Object -NoClobber -ErrorAction Stop
        import-module AzureAd -NoClobber -ErrorAction Stop
        #import-module CredentialManager -NoClobber -ErrorAction Stop
    }
    catch {
        write-host "Critical Error, unable to import all necessary Module"
        exit
    }
    
    #Determine $PSR Script Root path
    if ($null -ne $psISE) {
        $PSR = Split-Path -Path $psISE.CurrentFile.FullPath        
    }
    else {
        $PSR = $global:PSScriptRoot
    }
    if ($OutputPath -eq ".") {
        $OutputPath = Get-Location 
    }
    if ($LogPath -eq ".") {
        $LogPath = Get-Location 
    }
    $LogDate = "$($(get-date).Year)" + $(get-date).month.ToString("00") + $(get-date).Day.ToString("00") + "-" + $(get-date).Hour.ToString("00") + $(get-date).minute.ToString("00")
    Set-PSFLoggingProvider -Name 'LogFile' -FilePath "$LogPath\eKreta2SDS-$LogDate.Log" -Enabled $true
    Write-PSFMessage -Message "eKreta2SDS Script started. Version:$Version. Logpath: $LogPath" -level Host
    
    # Check Input paramters
    # School ID!
    # Check input school ID validity

    #Static parameters
    $OutputCSVDelimiter = ","
    $InputCSVDelimiter = ";"
    $SectionSeparator = " - "

    
    $OverrideTable = @{ }
    $OverrideFile = "$InputPath\Override.csv"
   
    $global:Usernames = @{ }
    $global:Azureadusers = @{ }
    $global:AzureADGroups = @{ }
    $global:Sections = @{ }
    #Helper function for unique SIDs
    $global:sid = 10000 #Global needed to works as static variable in subsequent enumerations

    #Check for pre-2020.03.31 generated SID for users with no ID in source
    $global:oldgeneratedsid=0

    #For School specific codes, we check the current SchoolID against these variables
    $SchoolIDB = "B"

    $Namingwithdots = 1
    $Namingnodots = 2
    
    $Naming = $Namingwithdots
        
    #****************************************************************************
    #   MAIN 
    #****************************************************************************
    try {
    
        if ($loglevel -match "TRANSCRIPT") {
            Start-transcript "$LogPath\eKreta2SDS-Transcript-$LogDate.Log"
        }

        try {
            InitOverride
            if (!$SkipAzureAdUserCheck) {
                InitAzureAD
            }
        }
        catch {
            Write-PSFMessage "Unable to initialize script!" -ErrorRecord $_
            throw "ERROR: Unable to initialize script"
        }

        #Import Excel1
        try {
            Write-PSFMessage -Level Host "Tanulók excel import elkezdődött"
            $Excel1 = Import-XLSX $Input_tanulok  | Where-Object {![string]::IsNullOrWhiteSpace($_.Vezetéknév) -and ![string]::IsNullOrWhiteSpace($_.Utónév) -and ![string]::IsNullOrWhiteSpace($_.'Oktatási azonosító')}
            if (!$Excel1) {
                throw 
            }
            Write-PSFMessage -Level Host "Tanulók excel import  $Input_tanulok befejeződött, $($Excel1.Count) sor betöltődött" -Tag "Report"
        }
        catch {
            Write-PSFMEssage  -Level Critical -Tag "Error" "Unable to Import Tanulok Excel file: $Input_tanulok" -ErrorRecord $_
            throw "ERROR: Unable to Import Tanulok Excel file: $Input_tanulok"
        }

        ###################################################
        # Teachers
        ###################################################
        <#Teachers
         0. Input:  Excel1-ből:  
            Pedagógus: Pedagógus teljes neve
            Tantárgy: Tantárgy neve
            'Pedagógus oktatási azonosító':  oktatási azonhosító
         1. Üres (tantárgy és pedagógus mezőnek Kötelező lennie.) sorok szűrése
         2. Add
        TeacherName: Pedagógus overrided UtóNév
        SIS ID: Pedagógus oktatási azonosító és PEdagógus alapján eredeti vagy generált SID
        #>

        #Teachers raw data selection from Excel, and additional columen declarations. Denormalized rows filtering fore uniqueness.
        $Teachers = $excel1 | ? { ($_.Tantárgy) -and ($_.Pedagógus) } | sort-object Pedagógus, 'Pedagógus oktatási azonosító'  -Unique |
        select-object Pedagógus, 'Pedagógus oktatási azonosító', @{Name = "TeacherName0"; expression = " " }, @{Name = "SIS ID"; expression = 'Pedagógus oktatási azonosító' }, @{Name = "TeacherFirstName"; expression = " " }, @{Name = "TeacherLastName"; expression = " " }, @{Name = "TeacherUserName"; expression = " " }, @{Name = "ADUserName"; expression = " " }
        
        # Column values creation in Teachers array
        $teachers | % {
            if ($LogLevel -match "DEBUG") {
                Write-PSFMessage -Level Debug "IN :$_"
            }
            $_.TeacherName0 = Get-OVerride "TeacherName" $_.Pedagógus $_.Pedagógus
            $_.'SIS ID' = Get-TeacherID $_.Pedagógus $_.'SIS ID' $true # Speciális SIS ID-t eredeti nem overrideolt névből kell venni!
            $_.TeacherName0 = Convert-Teachername $_.TeacherName0 $_.'SIS ID'       
            $_.TeacherFirstName = Get-UserFirstName -fullname $_.TeacherName0 -FlipFirstnameLastname:$FlipFirstnameLastname
            $_.TeacherLastName = Get-UserLastName -fullname $_.TeacherName0 -FlipFirstnameLastname:$FlipFirstnameLastname
            if ($Schoolid -eq $SchoolIdB) {
                $t = $_.TeacherLastName
                $_.TeacherLastName = $_.TeacherFirstName
                $_.TeacherFirstName = $t
            }
    

            #Get Username
            $TeacherUsername = Get-Username $_.TeacherName0 $_.'SIS ID'
        
            #Duplicated user name check. 
            $_.TeacherUsername = Get-UniqueUsername $TeacherUsername  $_.'SIS ID' $_.Pedagógus
            if ($DomainName) {
                #LocalAD Mode
                if ($null -ne $global:azureadusers[$_.TeacherUsername]) {
                    # the user account exists in Azure AD.
                    $_.ADUserName = $_.TeacherUserName
                }
            }       
            if ($LogLevel -match "DEBUG") {
                Write-PSFMessage -Level Debug "OUT:$_"
            }
        } # End While
    
        $allteacher = $teachers.count
    
        #Filter out missing SIS ID rows, empty usernames and refilter for uniqueness. Get-Teachername can return with empoty username!
        $teachers2 = $teachers | ? { ![string]::IsNullOrWhiteSpace($_.'SIS ID') -and ![string]::IsNullOrWhiteSpace($_.TeacherUsername) } | sort-object TeacherName0, 'SIS ID' -Unique
        Write-PSFMessage -tag "Report" "Total $allteacher  teacher record,  $($teachers2.count) unique records. Missing SIDs or Username after processing:  $($Allteacher-$teachers2.count)"

        #Throw exceptions if there are still for Empty SID
        $chk_t1 = $Teachers | ? { !$_.'SIS ID' }
        if ($chk_t1.count -gt 0) {
            Write-PSFMessage -level Critical -tag "Error" "*** Tanárok hiányzó egyedi oktatási azonosítói ***"
            $chk_t1 | % { Write-PSFMessage -level Host """"$_.'Pedagógus'"""" }
            throw "ERROR: Kezeljék a hiányzó tanári oktatói azonosítókat"
        }
 
        #User records needed to create in Local AD mode
        if ($DomainName) {
            # Local AD MODE. LocalADusers: note exist in AzureAD
            $LocalADCreateTeachers = $teachers2 | ? { [string]::IsNullOrWhiteSpace($_.ADUserName) } 
            $teachers2 = $teachers2 | ? { ![string]::IsNullOrWhiteSpace($_.ADUserName) }   #remove non AD users from SIS Export users
            if ($LocalADcreateTeachers.Count -gt 0) {
                Write-PSFMessage -level Host -tag "Report" "Needed teacher  user account in Local AD:  $($LocalADcreateTeachers.Count)"
                $LocalADTeachersExport = $LocalADCreateTeachers | Select-Object @{Name = "First Name"; expression = 'TeacherFirstName' }, @{Name = "Last Name"; expression = 'TeacherLastName' } , @{Name = "Username"; expression = 'TeacherUsername' } , @{Name = "Password"; expression = " " } , 'SIS ID' 
                $null = $LocalADTeachersExport | % { $_.Password = Generate-TeacherPassword $_.'SIS ID' }
                $LocalADTeachersExport | export-csv "$outputPath\LocalADTeacher.csv" -delimiter $OutputCSVDelimiter -Encoding UTF8 -NoTypeInformation         
            }
            else {
                Remove-Item -force -confirm:$false -path "$outputPath\LocalADTeacher.csv" -ErrorAction silentlycontinue
            }
        }

        #Teachers
        $teachersexport = $Teachers2 | select-object *, @{Name = "School SIS ID"; expression = { $schoolid } },
        @{Name = "First Name"; expression = { $_.TeacherFirstName } },  
        @{Name = "Last Name"; expression = { $_.TeacherLastName } },
        @{Name = "Username"; expression = {
                if ($AddUpnSuffix) {
                    $_.TeacherUsername 
                } 
                else { 
                    $_.TeacherUserName.Split("@")[0] 
                } } 
        },
        @{Name = "Password"; expression = { Generate-TeacherPassword $_.'SIS ID' } }

        if ($teachersexport) { 
            $null = $teachersexport | Select-object "SIS ID", "School SIS ID", "First name", "Last Name", "UserName", "Password" | 
            export-csv "$outputPath\teacher.csv" -delimiter $OutputCSVDelimiter -Encoding UTF8 -NoTypeInformation    
            Write-PSFMessage -level host "Tanárok exportálása befejeződött (teacher.csv), $($teachersexport.count) tanár."
        }
        else {
            #$teacherexport $null, because no record in array
            Write-PSFMessage -Level Warning "No SDS exportable teachers. Teachers.csv not created!"    
            Remove-Item -force -confirm:$false -path "$outputPath\teacher.csv" -ErrorAction silentlycontinue
        }

        ###################################################
        #Tanulok kezelése 
        ###################################################

        $students = $excel1 | select-object Vezetéknév, Utónév, "Oktatási azonosító" | sort-object "Oktatási azonosító" -unique

        #Throw exceptions for Empty SID.
        $chk_s1 = $student | ? { !$_.'SIS ID' }
        if ($chk_s1.count -gt 0) {
            Write-PSFHost -level Critical -Tag "ERROR" "*** Tanulók hiányzó egyedi oktatási azonosítóval ***"
            $chk_s1 | % { write-PSFhost -Level host """"$_.'Vezetéknév' $_.'Utónév'"""" }
            throw "ERROR: Kezeljék a hiányzó tanulói azonosítókat"
        }

        $students2 = $students | select-object * ,
        @{Name = "SIS ID"; expression = { $_.'Oktatási azonosító' } },
        @{Name = "School SIS ID"; expression = { $schoolid } },
        @{Name = "First Name"; expression = " " },
        @{Name = "Last Name"; expression = " " },
        @{Name = "Username"; expression = " " },
        @{Name = "Password"; expression = " " },
        @{Name = "ADUserName"; expression = " " },
        @{Name = "StudentFullName"; Expression = " " }

        $students2 | % {
            if ($LogLevel -match "DEBUG") {
                Write-PSFMessage -Level Debug  "IN :$_"
            }
            if ($FlipFirstnameLastname) {
                $_.'First Name' = Get-Override "StudentID2FirstName" $_.'SIS ID' $_.Vezetéknév
                $_.'Last Name' = Get-Override "StudentID2LastName" $_.'SIS ID' $_.UtóNév
                $_.StudentFullName = "$($_.'First Name') $($_.'Last Name')"
            } else {
                $_.'First Name' = Get-Override "StudentID2FirstName" $_.'SIS ID' $_.UtóNév
                $_.'Last Name' = Get-Override "StudentID2LastName" $_.'SIS ID' $_.Vezetéknév
                $_.StudentFullName = "$($_.'Last Name') $($_.'First Name')" # From overrided Firstname lastname. # "$_.StudentLastName $_.StudentFirstName" give strange output!
            }

            if ( $Schoolid -eq $SchoolIdB) {
                $t = $_.'Last Name'
                $_.'Last Name' = $_.'First Name'
                $_.'First Name' = $t
            }
                        
            #Get Username
            $StudentUsername = get-Username $_.StudentFullName $_.'SIS ID'
    
            #Duplicated user name check. 
            $_.Username = Get-UniqueUsername $StudentUsername  $_.'SIS ID' $_.StudentFullName
            if ($DomainName) {
                #LocalAD Mode
                if ($null -ne $global:azureadusers[$_.Username]) {
                    # there are exist the user acocunt in Azure AD
                    $_.ADUserName = $_.Username
                }
            }

            if ($LogLevel -match "DEBUG") {
                Write-PSFMessage -Level Debug  "OUT :$_"
            }
    
        } #End While

        $allstudents = $students2.count

        #Filter out missing SIS ID rows, empty usernames and refilter for uniqueness. Get-Teachername can return with empoty username!
        $students2 = $students2 | ? { (![string]::IsNullOrWhiteSpace($_.'SIS ID')) -and (![string]::IsNullOrWhiteSpace($_.Username)) } | sort-object StudentFullName, 'SIS ID' -Unique
        Write-PSFMessage -tag "Report" "Total $allstudents  student record,  $($students2.count) unique records. Missing SIDs or Username after processing:  $($allstudents-$students2.count)"



        #User records needed to create in Local AD mode
        if ($DomainName) {
            # Local AD MODE
            $LocalADCreateStudents = $students2 | ? { [string]::IsNullOrWhiteSpace($_.ADUserName) } 
            $students2 = $students2 | ? { ![string]::IsNullOrWhiteSpace($_.ADUserName) } 
    
            if ($LocalADCreateStudents.Count -gt 0) {
                Write-PSFMessage -tag "Report" "Needed student  user account in Local AD:  $($LocalADCreateStudents.Count)"                
                
                $LocalADCreateStudentsExport = $LocalADCreateStudents | Select-Object @{Name = "First Name"; expression = 'First Name' }, @{Name = "Last Name"; expression = 'Last Name' } , @{Name = "Username"; expression = 'Username' } , @{Name = "Password"; expression = " " } , "SIS ID" 
                $null = $LocalADCreateStudentsExport | % { $_.Password = Generate-StudentPassword $_.'SIS ID' }
                $LocalADCreateStudentsExport | export-csv "$outputPath\LocalADstudent.csv" -delimiter $OutputCSVDelimiter -Encoding UTF8 -NoTypeInformation

            }
            else {
                Remove-Item -force -confirm:$false -path "$outputPath\LocalADstudent.csv" -ErrorAction silentlycontinue
            }        
        }
    
        Write-PSFMessage -tag "Report" "Total $allstudents Unique student record."
        Write-PSFMessage -tag "Report" "Total $($students2.count)  student record in the output."

        if ( $loglevel -match "DEBUG") {
            Write-PSFMessage -level DEBUG "Processed students table (NO PASSWORD!): $students2"
        }


        $studentsExport = $students2 | Select-object "SIS ID", "School SIS ID", "First name", "Last Name",  
        @{Name = "Username"; expression = { if ($AddUpnSuffix) { $_.Username } else { $_.Username.Split("@")[0] } } }, @{Name = "Password"; expression = { Generate-StudentPassword $_.'SIS ID' } }
    
        if ($studentsExport) {
            $studentsExport | export-csv "$outputPath\student.csv" -delimiter $OutputCSVDelimiter -Encoding UTF8 -NoTypeInformation
            Write-PSFMessage -level host "Tanulók exportálása befejeződött (student.csv), $($studentsExport.count) tanuló."
        }
        else {
            #$studentExport $null, because no record in array
            Write-PSFMessage -Level Warning "No SDS exportable Students. Students.csv not created!"    
            Remove-Item -force -confirm:$false -path "$outputPath\Student.csv" -ErrorAction silentlycontinue
        }

        #no records in teacher or students. Delete both CSV and exit with error
        if (($null -eq $studentsExport) -or ($null -eq $teachersexport) -and ($null -eq $DomainName)) {
            Write-PSFMEssage -level Critical "No student or teacher rekord to update/create in SDS! STOP"
            exit
            #TODO ERROR report!
        }


        ###################################################
        # Sections 
        ###################################################

        #tantárgy/csoport egyedileg lekérdezve


#        $sec = $excel1 | select-object "Tantárgy", "Osztály / csoport" | sort-object  'Tantárgy'  -unique
        $sec = $excel1 | select-object "Tantárgy", "Osztály / csoport" | sort-object  -Property @{Expression = { Get-SectionName $_."Tantárgy"  $_."Osztály / csoport" } }  -unique

        Write-PSFMessage -Tag "Report" "Tantárgy és osztály lekérdezés összes rekord: $($sec.count)"

        $sec2 = $sec | select-object *,
        @{Name = "SIS ID"; expression = { fSId } },
        @{Name = "School SIS ID"; expression = { $schoolid } },
        @{Name = "Section Name"; expression = " " },
        @{Name = "Course Name"; expression = " " } 
        $null = $sec2 | % { 
            $_.'Section Name' = Get-SectionName $_."Tantárgy"  $_."Osztály / csoport" 
            $_.'Course Name' = $_."Osztály / csoport" 
        }
        
        # and Export $sec2|ft
        $SectionExport = $sec2 | select-object "SIS ID", "School SIS ID", @{Name = "Section Name"; expression = { $_.'Section Name' } }, "Course name" 
        
        # Export Sections
        $SectionExport | export-csv "$outputPath\section.csv" -delimiter $OutputCSVDelimiter -Encoding UTF8 -NoTypeInformation
        Write-PSFMessage -level host -tag "report" "Tanórák exportálása befejeződött (section.csv), $($SectionExport.count) tanóra."

       

        
        ###################################################
        #Studentenrollment
        ###################################################
        $Sec2St = $excel1 | select-object "Tantárgy", "Osztály / csoport", "Oktatási azonosító", 
        @{Name = "Section Name"; expression = { (Get-SectionName $_."Tantárgy"  $_."Osztály / csoport" ) } }
        Write-PSFMessage -tag Report "Tanuló tantárgy ,osztály lekérdezés összes rekord: $($sec2st.count)"

        $StudentEnroll = join-object -Left $sec2st  -Right $sec2 -LeftJoinProperty "Section Name" -RightJoinProperty "Section Name" -prefix L
        $StudentEnroll | select-object @{Name = "Section SIS ID"; expression = { $_.'LSIS ID' } },
        @{Name = "SIS ID"; expression = { $_.'Oktatási azonosító' } } | export-csv "$outputPath\StudentEnrollment.csv" -delimiter "," -Encoding UTF8 -NoTypeInformation
        Write-PSFMessage -Tag "Report" -level host "Tanulók órákhoz rendelése exportálás befejeződött (StudentEnrollment.csv), $($StudentEnroll.count) összerendelés."

       
        
        ###################################################
        # TeacherRoster
        ###################################################
        if ($null -ne $teachers2) {
            #there are teachers in output csv
            $Sec2T = $excel1 | select-object "Tantárgy", "Osztály / csoport", "Pedagógus oktatási azonosító", "Pedagógus",
            @{Name = "Section Name"; expression = { (Get-SectionName $_."Tantárgy"  $_."Osztály / csoport" ) } }, @{Name = "SIS ID"; expression = 'Pedagógus oktatási azonosító' }
            Write-PSFMessage -Tag "Report" "Tanár tantárgy ,osztály lekérdezés összes rekord: $($sec2t.count)"

            
            $null = $sec2t | % {
                #teacher SID override mgmt,
                if ($loglevel -match "DEBUG") {
                    Write-PSFMessage -level DEBUG "Tanár aktuális rekord: $_"
                }
                $_.'SIS ID' = Get-OverRide "TeacherName2ID"  $_.Pedagógus  $_.'SIS ID'
                $_.'SIS ID' = Get-TeacherID $_.Pedagógus $_.'SIS ID' $false 
            }

            # unique filtering and safety check for missing SIS ID (theoritecally couldn't be missing at this point!)
            $sec2t2 = $sec2t | ? { ![string]::IsNullOrWhiteSpace($_.'SIS ID') } | sort-object "Section Name", "SIS ID" -unique  #

            #Teacher SID to table

            $sec2t3 = join-object -left $sec2t2 -right $Teachers2 -LeftJoinProperty 'SIS ID' -RightJoinProperty 'SIS ID'  -prefix L -Type AllInLeft
            $TeacherEnroll = join-object -Left $sec2t3  -Right $sec2 -LeftJoinProperty "Section name" -RightJoinProperty "Section Name" -prefix L2

            $TeacherEnroll | select-object @{Name = "Section SIS ID"; expression = { $_.'L2SIS ID' } },
            @{Name = "SIS ID"; expression = { $_.'LSIS ID' } } | 
            export-csv "$outputPath\TeacherRoster.csv"  -delimiter $OutputCSVDelimiter -NoTypeInformation -Encoding UTF8  
            Write-PSFMessage -level host -tag "Report" "Tanárok órákhoz rendelése exportálása befejeződött (TeacherRoster.csv), $($TeacherEnroll.count) összerendelés."
        }

        ###################################################
        # School
        ###################################################
        
        $Schoolinfo =  @([pscustomobject]@{'SIS ID'=$schoolid;Name=$SchoolName;Address=$SchoolAddress})
        $Schoolinfo | export-csv "$outputPath\School.csv" -delimiter $OutputCSVDelimiter -Encoding UTF8 -NoTypeInformation
        
        ###################################################
        # GONDVISELŐK
        ###################################################
        
        if (![string]::IsNullOrWhiteSpace($Input_gondviselok)) {
            #Import Excel2
            try {
                Write-PSFMessage -Level Host "Gondviselők excel import elkezdődött"
                $excel2 = Import-XLSX $Input_gondviselok
                if (!$excel2) { 
                    throw
                }
                Write-PSFMessage -Level Host "Gondviselok excel import befejeződött, $($excel2.Count) sor betöltődött"
                Write-PSFMessage -Tag "Report" "Number of  record in $Input_gondviselok excel $($excel2.Count)"
            }
            catch {
                Write-PSFMEssage -Level Critical -Tag "Error"  "Unable to Import Gondviselok Excel file: $Input_gondviselok" -ErrorRecord $_
                throw "ERROR: Unable to Import Gondviselok Excel file: $Input_gondviselok"
            }

            #Guardianrelationship
            $Users = $excel2 | ? { ($_.'E-mail cím'.Length) -gt 0 } | select-object 'Gondviselő neve', Telefon, 'E-mail cím' | sort-object 'Gondviselő neve', Telefon, 'E-mail cím' -Unique
            Write-PSFMessage -Level Host  "Egyedi Gondviselok száma email cím szűrése után: $($Users.Count) " -Tag "Report"

            $global:sid = 1000000
            $Users2 = $users | select-object @{Name = "Email"; expression = { $_.'E-mail cím' } },
            @{Name = "First Name"; expression = { get-UserFirstname -fullname $_.'Gondviselő neve' -FlipFirstnameLastname:$FlipFirstnameLastname} },
            @{Name = "Last Name"; expression = { get-UserLastname -fullname $_.'Gondviselő neve' -FlipFirstnameLastname:$FlipFirstnameLastname} },
            @{Name = "SIS ID"; expression = { $(fSId).ToString() } }


            $Users2 | select-object Email, 'First Name', 'Last Name', 'SIS ID' |
            export-csv "$outputPath\user.csv"  -delimiter $OutputCSVDelimiter -NoTypeInformation -Encoding UTF8  
            Write-PSFMessage -level host -Tag "Report" "Gondviselok exportálása befejeződött (user.csv), $($Users2.count)."

            $GuardianRelationShip = $excel2 | ? { ($_.'E-mail cím').Length -gt 0 } |
            select-object @{Name = "SIS ID"; expression = { $_.'Oktatási azonosító' } }, 
            @{Name = "Email"; expression = { $_.'E-mail cím' } },
            @{Name = "Role"; expression = { $_.'Rokonság foka' } }

            $GuardianRelationSHip | select-object 'SIS ID', Email, Role |
            export-csv "$outputPath\GuardianRelationShip.csv"  -delimiter $OutputCSVDelimiter -NoTypeInformation -Encoding UTF8  
            Write-PSFMessage -level host -Tag "Report" "Gondviselok tanulókhoz rendelése exportálása befejeződött (GuardianRelationShip.csv), $($GuardianRelationSHip.count) összerendelés."
            $eKretaResult = "OK"
        }
    }
    catch {
        $Exception = $_.Exception
        Write-PSFMessage -Level Critical "eKreta2SDS Error in Line:  $($Exception.ErrorRecord.Invocationinfo.ScriptLineNumber)"  -ErrorRecord $_ 
        if ($Loglevel -match "DEBUG") {
            Write-PSFMessage -Level Debug "eKreta2SDS Error    $($Exception.ErrorRecord)"
            Write-PSFMessage -Level Debug "eKreta2SDS Error  Stack  $($Exception.ErrorRecord.ScriptStackTrace) "
        }
        $eKretaResult = "ERROR"
    }
    finally {
        Write-PSFMessage -level Host "eKreta2SDS Script Finished." 
        if ($loglevel -match "TRANSCRIPT") {
            Stop-transcript "$LogPath\eKreta2SDS-Transcript-$LogDate.Log"
        }
    }
    
    Return $eKretaResult
}


Export-ModuleMember -Function  eKreta2Convert

