# Copyright (c) 2018 Kevin Ott
# Licensed under the MIT License
# See the LICENSE file in the project root for more information.


Function Create-ADUser{
    <#
    .SYNOPSIS
        Creates an Active Directory user.
    .DESCRIPTION
        This is a function for creating a new AD user without needing the Active Directory Powershell 
        module loaded by utilizing the DirectoryEntry .Net class. Will create users in the User Container
        of the current domain by default, specify the Distinguished Name of a Container or Organizational Unit
        as a Path to target a different location or different domain. Not all standard account parameters are
        supported, if you need more than the basic parameters, you should probably consider using New-ADUser
        from the Powershell module.
    .EXAMPLE
        Create-ADUser -Name TestUser -Password $password -SamAccountName TestUser -DisplayName TestingUser -FirstName Testing -LastName User -Description 'User for testing' -Path 'OU=Test,DC=example,DC=COM' -AccountEnabled -UserMustChangePwd
        Creates a new user account called "TestUser" with a password, sets the standard attributes, sets the account to be enabled, and 
        specifies the user must change password at next login. User will be created in the OU "Test" in the domain "example.com"
    .EXAMPLE
        Create-ADUser -Name TestUser2 -Password $password
        Creates a new user account called "TestUser2", with a SamAccountName of "TestUser2", in the Users Container of the current domain.
    .PARAMETER Name
        The name of the new AD user object, alias of "CN", required parameter.
    .PARAMETER SamAccountName
        The SamAccountName of the new user, will default to the same as "Name" if left blank.
    .PARAMETER DisplayName
        The display name of the new user.
    .PARAMETER FirstName
        The first name of the new user.
    .PARAMETER LastName
        The last name of the new user.
    .PARAMETER Description
        The desciption to set on the new user.
    .PARAMETER Path
        The distinguished name of an Active Directory OU or CN in which to create the new user.
        If not specified, the path will default to the Users CN of the current domain, if the
        executing machine is not in a domain, the script will error. Specify the DN of a CN or OU
        in any domain where the executing account has access to create an account.
    .PARAMETER AccountEnabled
        Specifies that the new account should be enabled. By default the new account will be disabled,
        this mirrors the functionality of New-ADUser.
    .PARAMETER UserMustChangePwd
        Sets the new account to require a password reset at next login. Cannot be specified along with
        "PasswordNeverExpires".
    .PARAMETER PasswordNeverExpires
        Sets the new account to never require a password reset. Cannot be specified along with "UserMustChangePwd".
    .PARAMETER Password
        String value that represents the password to set for the account. Cannot be specified along with "PasswordNotRequired",
        however either "PasswordNotRequired" or "Password" must be specified.
    .PARAMETER PasswordNotRequired
        This sets the new ad user to be a password-less account. Specifying this parameter with "AccountEnabled" and without
        "UserMustChangePwd" will generate a warning indicating how bad of an idea that is.
    .NOTES
        Filename: Function Create-ADGroup.ps1
        Version: 1.0
        Date: 7/30/2018
        Author: Kevin Ott
    .LINK
        https://github.com/KevOtt/AD-Tools
    #>
    [cmdletbinding()]

    Param(
        [Parameter(Mandatory=$true)]
        [Alias('CN')]
        [string]$Name,
        [string]$SamAccountName,
        [String]$DisplayName,
        [string]$FirstName,
        [string]$LastName,
        [string]$Description,
        [string]$Path,
        [switch]$AccountEnabled,
        [switch]$UserMustChangePwd,
        [switch]$PasswordNeverExpires,
        [Parameter(ParameterSetName='Password')]
        [ValidateLength(1,255)]
        [string]$Password,
        [Parameter(ParameterSetName='NoPassword')]
        [switch]$PasswordNotRequired
        #todo: add support for all of the descriptive parameters, e.g. address, phone, etc.
        # If you are looking for all those things, you probably should be using New-ADUser from the ad module
    )

    ## Parameter checking

    if($UserMustChangePwd -eq $true -and $PasswordNeverExpires){
        # We have two parameters sets, of which one set is optional
        # Throwing error here is far easier than using param sets and throws a more reasonable error
        throw 'UserMustChangePWd and PasswordNeverExpires cannot be specified together'
    }
  
    # If no path specified, default to users container of current domain, if we can't resolve
    # a current domain, throw exception
    if($Path -eq ''){
        TRY{
            $d = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
            }
        CATCH{
            throw 'Unable to resolve a current domain, PC may not be a domain member. Specify a DN as a Path.'
            }
        $pathArgument = ('LDAP://CN=Users,' + (@(ForEach($s in ($d.Split('.'))) {('DC=' + $s)}) -join ','))
        }
    else{
        # If a path was provided, we'll check that we can find it and that it is an OU or CN
        $directorySearcher = New-Object ([System.DirectoryServices.DirectorySearcher])
        $directorySearcher.SearchRoot = ('LDAP://' + (@(($Path).Split(',') | Where-Object{$_ -like 'DC=*'}) -join ','))
        $directorySearcher.Filter = "DistinguishedName=$Path"
        TRY{
            $r = $directorySearcher.FindOne()
            }
        CATCH{
            #Ignoring exceptions on FindOne, we'll throw a better exception below
            }
        if($r -eq $null -or ($r.Properties.objectclass -notcontains 'container' -and $r.Properties.objectclass -notcontains 'OrganizationalUnit')){
            throw 'Provided Path cannot be found or is not either a Container or Organizational Unit'
            }

        $pathArgument = ('LDAP://' + $Path)
        }
        Write-Verbose "User will be created in $pathArgument"

    ## Create new DirectoryEntry

    TRY{
        $directoryEntry = New-Object ([System.DirectoryServices.DirectoryEntry]) -ArgumentList $pathArgument
        }
    CATCH{
        Write-Error -Exception $_.Exception
        return 1
        }

    # If we don't have a valid DirectoryEntry object, throw exception
    if($directoryEntry -eq $null){
        throw 'Could not find directory or directory path. Specify a valid DN'
        }

    # Create new DirectoryEntry for new user
    $newUser = $directoryEntry.Children.Add("cn=$Name",'user')
    if($SamAccountName -eq ''){
        $SamAccountName = $Name
        }

    if($UserMustChangePwd -eq $true){
        $pwdLastSet = 0
        }
    else{
        $pwdLastSet = -1
        }

    # Set each attribute
    if($SamAccountName -ne ''){$newUser.Properties['SamAccountName'].Value = $SamAccountName}
    if($DisplayName -ne ''){$newUser.Properties['DisplayName'].Value = $DisplayName}
    if($FirstName -ne ''){$newUser.Properties['givenName'].Value = $FirstName}
    if($LastName -ne ''){$newUser.Properties['sn'].Value = $LastName}
    if($Description -ne ''){$newUser.Properties['Description'].Value = $Description}
    $newUser.Properties['pwdLastSet'].Value = $pwdLastSet

    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
    $email = '';
    if($FirstName -And $LastName){
        $firstLetter = $FirstName[0]
        $email = "${firstLetter}.${LastName}@${domain}".ToLower()
    }else{
        $email = "${SamAccountName}@${domain}".ToLower()
    }
    $newUser.Properties['mail'].Value = $email
    $newUser.Properties['userPrincipalName'].Value = "${SamAccountName}@${domain}"
   
    # probably a cleaner way to iterate these, will re-look if the rest of the standard attribs are added

    # Determine UserAccountControl value
    <#
    https://docs.microsoft.com/en-us/windows/desktop/adschema/a-useraccountcontrol
    There's a lot of these, we're ignoring most of them. Setting referenced:
    0x00000002	ADS_UF_ACCOUNTDISABLE The user account is disabled.
    0x00000020 ADS_UF_PASSWD_NOTREQD No password is required - Note this setting is ignored if you set a password.
    0x00000200 ADS_UF_NORMAL_ACCOUNT This is a default account type that represents a typical user.
    0x00010000 ADS_UF_DONT_EXPIRE_PASSWD The password for this account will never expire.
    #>

    $userAccountControl = 0x00000202
    if($PasswordNeverExpires -eq $true){
        $userAccountControl = ($userAccountControl -bor 0x00010000)
        }
    if($PasswordNotRequired -eq $true){
        $userAccountControl = ($userAccountControl -bor 0x00000020)
            # Can only set enabled now if we are setting PasswordNotRequired
            if($AccountEnabled -eq $true){
                $userAccountControl = ($userAccountControl -bxor 0x00000002)
            }
            if($UserMustChangePwd -ne $true -and $AccountEnabled -eq $true){
                Write-Warning 'For this new user, a password will not be required and user will not be required to change.' -WarningAction Continue
                }
        }

    $newUser.Properties['UserAccountControl'].Value = $userAccountControl

    Write-Verbose 'Attempting creation of user...'
    # Attempt create new user
    TRY{
        $newUser.CommitChanges()
       }
    CATCH{
        Write-Error -Exception $_.Exception
        return 1
        }


    ## Post user create actions

    # If we have a password specified, attempt to set
    if($Password -ne ''){
        Write-Verbose 'Setting password...'
        # The set password method doesn't seem to take a secure string,
        # need to see if there is a way to do this without the pass in clear text
        $newUser.Invoke("SetPassword", $Password)
        # If we set a password and want the user to have to reset the pass
            if($UserMustChangePwd -eq $true){
                $newUser.properties["pwdLastSet"].Value = 0
                $newUser.CommitChanges()
            }

        if($AccountEnabled -eq $true){
            Write-Verbose 'Enabling account...'
            <#
            As best as I can tell we can only enable the account after the password is set unless we are setting ADS_UF_PASSWD_NOTREQD. 
            I think this is because domain password policy won't allow setting a blank password, and after lots of googling I can't find 
            a way to set the password at the time of user creation. Please let me know if there is a better way.
            #>
            $userAccountControl = ($userAccountControl -bxor 0x00000002)
            $newUser.properties["UserAccountControl"].Value = $userAccountControl
            $newUser.CommitChanges()
        }
    }
    Write-Verbose 'User creation completed successfully'

    return 0
}


