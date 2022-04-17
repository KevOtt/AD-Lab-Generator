# Copyright (c) 2022 Kevin Ott
# Licensed under the MIT License
# See the LICENSE file in the project root for more information.

<# 
.SYNOPSIS
    This tool can be used to populate an Active Directory lab environment 
    with a randomized setup of users and groups for testing purposes.
.DESCRIPTION
    This script and config files was created to provide a way to populate an
    AD lab with groups and users for use in testing of other AD tools and scripts.
    The script will create randomized user names based on a configurable seed file
    called Names.txt and create groups defined in Groups.txt.

    In the default mode, a role-based access model is followed, and users are placed
    into a single "role group" such as "Sales" and "Engineering". These role groups are then placed
    into dummy "access groups". To make it more relavant to most real world AD setups, the users
    are also placed into a random number of access groups. No access is actually allocated
    by this process, we're just creating the groups and users.

    To create users that are just placed into dummy access groups, run with the switch "-NoRoles",
    or to add only the role groups into access groups, so no users are placed into access groups, run
    with the switch "CleanRoles".

    For now, the tool will only create all groups and users in a single OU or CN. All objects will be
    created in the Users Container by default; otherwise specify the Distinguished Name of an existing
    OU or CN for the argument "TargetLocation" to create all objects in that location.
.EXAMPLE
	& '.\Generate AD Lab.ps1' -Domain 'Example.com'
    Populates objects into the Users Container of the domain "Example.com", with the default setup. 
.EXAMPLE
	& '.\Generate AD Lab.ps1' -Domain 'Example.com' -TargetLocation 'OU=TestLab,DC=Example,DC=Com'
    Populates objects into the OU "TestLab" of the domain "Example.com", with the default setup. 
.EXAMPLE
	& '.\Generate AD Lab.ps1' -Domain 'Example.com' -TargetLocation 'OU=TestLab,DC=Example,DC=Com' -NumberOfUsers 50 -CleanRoles -ExportPasswords
    Populates objects into the OU "TestLab" of the domain "Example.com", emulating proper role-based access.
    Passwords for created users will be output in a new file created in the script directory. 50 users will be
    created.
.PARAMETER Domain
    The full name of the domain which will be populated, required parameter.
.PARAMETER CleanRoles
    Specifies that users should be added only to a role group, and not to additional access groups.
    Simulates a proper role-based access setup.
.PARAMETER NoRoles
    Specifies that any groups in Groups.txt marked as type "role" will not be created, and users
    will be added to "access" groups only, and not to any "role" type groups. Simulates an environment
    with no role based access.
.PARAMETER NumberOfUsers
    Total number of users to generate, valid numbers are 1 to 10,000. The default number of users is 40.
    Note that if you do not have sufficient name seeds in Names.txt, you may run into failures if the specified 
    number of users is too high.
.PARAMETER TargetLocation
    The OrganizationalUnit or Container where the group and user objects should be created. At this time the tool
    only supports creating all objects in a single place. The OU or CN specified must already exist in the target 
    domain. If no location is specified, the Users container will be used by default, it is reccomended to create the
    lab objects in a separate location.
.PARAMETER ExportPasswords
    Enabling this switch will write a file to the script directory that contains all of the passwords for the created
    users. Useful if you want to test something and don't want to reset all of the user passwords. Otherwise user passwords
    will not be presented.
.PARAMETER UserNameSeedFile
    Specify an alternate location for the username seed file, otherwise by default the script will look in the config folder
    for a file.
.PARAMETER GroupsConfFile
    Specify an alternate location for the group configuration file, otherwise by default the script will look in the config folder
    for a file.
.NOTES
    Filename: Generate AD Lab.ps1
    Version: 1.0
    Date: 8/20/2018
    Author: Kevin Ott
#Requires -Version 3
.LINK
    https://github.com/KevOtt/AD-Lab-Generator
#> 

Param(
    [cmdletbinding()]
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    [switch]$CleanRoles,
    [switch]$NoRoles,
    [ValidateRange(1,10000)]
    [int]$NumberOfUsers = 40,
    [string]$TargetLocation,
    [switch]$ExportPasswords,
    [string]$UserNameSeedFile,
    [string]$GroupsConfFile
)

# Determine script location
# ScriptDir is used for the config files, dot-sourcing, and password export
if($psISE -eq $null){
    $ScriptDir = ($MyInvocation.MyCommand.Path | Split-Path -Parent)
    }
else{
    $ScriptDir = ($psISE.CurrentFile.FullPath | Split-Path -Parent)
    }

## Dot-source functions

TRY{
    .($ScriptDir + '\Functions\Create-ADGroup.ps1')
    .($ScriptDir + '\Functions\Create-ADUser.ps1')
    .($ScriptDir + '\Functions\Get-RandomAccessGroups.ps1')
    .($ScriptDir + '\Functions\Modify-ADGroupMembers.ps1')
    .($ScriptDir + '\Functions\New-Password.ps1')
    .($ScriptDir + '\Functions\Query-ADObject.ps1')
    }
CATCH{
    throw ('Unable to locate dependent file: ' + $_.Exception)
    }

Write-Output 'Starting AD Lab Generation'

## Validate script arguments

# Check role parameters
if($CleanRoles -eq $true -and $NoRoles -eq $true){
    throw 'Swiches -CleanRoles and -NoRoles cannot be specified together'
    }

# For user config file if no value specified, check for default path, stop if not found
if($UserNameSeedFile -eq '' -or $UserNameSeedFile -eq $null){
        $p = '\Config\Names.txt'
        if(Test-Path ($ScriptDir + $p)){
            $UserNameSeedFile = ($ScriptDir + $p)
            }
        else{
            throw 'User name seed config file not found in default location and no path specified.'
            }
        }
# Users config file location specified, check for existence
else{
    if(!(Test-Path $UserNameSeedFile)){
        throw ('User seed config file not found in specified location')
        }
    }
# For group config file if no value specified, check for default path, stop if not found
if($GroupsConfFile -eq '' -or $GroupsConfFile -eq $null){
        $p = '\Config\Groups.txt'
        if(Test-Path ($ScriptDir + $p)){
            $GroupsConfFile = ($ScriptDir + $p)
            }
        else{
            throw 'Groups config file not found in default location and no path specified.'
            }
        }
# Group config file specified, check for existance
else{
    if(!(Test-Path $GroupsConfFile)){
        throw ('Groups config file not found in specified location')
        }
    }

## Determine the target OU

# If no path specified, default to users container of targeted domain
if($TargetLocation -eq '' -or $TargetLocation -eq $null){
    $TargetLocation = ('CN=Users,' + (@(ForEach($s in ($Domain.Split('.'))) {('DC=' + $s)}) -join ','))
    }
else{
    # If a TargetOU was provided, we'll check that we can find it in the specified Domain and that it is an OU or CN
    $directorySearcher = New-Object ([System.DirectoryServices.DirectorySearcher])
    $directorySearcher.SearchRoot = ('LDAP://' + (@(ForEach($s in ($Domain.Split('.'))) {('DC=' + $s)}) -join ','))
    $directorySearcher.Filter = "DistinguishedName=$TargetLocation"
    TRY{
        $r = $directorySearcher.FindOne()
        }
    CATCH{
        # Ignoring exceptions on FindOne, we'll throw a better exception below
        }
    if($r -eq $null -or ($r.Properties.objectclass -notcontains 'container' -and $r.Properties.objectclass -notcontains 'OrganizationalUnit')){
        throw 'Provided TargetOU cannot be found or is not either a Container or Organizational Unit'
        }
    }
Write-Verbose "Lab objects will be created in $TargetLocation"


## Get configs

# For both config files, we ignore any line with '#' and convert each entry to a PSObject,
# assuming the entries are comma separated values in the right order

# Get group config file content
$Groups = @()
Get-Content $GroupsConfFile -ErrorAction Stop | Where-Object {$_ -notlike '#*' -and $_ -ne ''} -ErrorAction Stop | ForEach-Object{
    # Continue on any errors, we'll catch format problems below
    if($_.contains(',') -and $_[$_.count -1] -ne ',' -and $_[0] -ne ','){
        $g = (New-Object -TypeName psobject -Property @{'GroupName' = ($_.split(',')[0]).ToString().TrimStart();'Type' = ($_.split(',')[1]).ToString().TrimStart()})
        }
    else{
        # If entry isn't in a format that we can parse, skip it
        Write-Warning -Message 'Cannot parse entry in group config file, skipping entry...' -WarningAction Continue
        return
        }
    # Checking for value unique-ness, skip if not
    if($Groups -contains $g){
        Write-Warning -Message ("Duplicate group " + $g.GroupName + " found, skipping...") -WarningAction Continue
        return
        }
    # Check for missing property, skip if true
    if($g.GroupName -ne '' -and $g.Type -ne ''){
        $Groups += $g
        }
    else{
        Write-Warning -Message 'Skipping group due to missing information...' -WarningAction Continue
        }
    }

# Get user name seed config file content
$NameSeeds = @()
Get-Content $UserNameSeedFile -ErrorAction Stop | Where-Object {$_ -notlike '#*' -and $_ -ne ''} -ErrorAction Stop | ForEach-Object{
    # Not checking for uniquness, duplicate entries will be allowed.
    if($_.contains(',') -and $_[$_.count -1] -ne ',' -and $_[0] -ne ','){
        $n = (New-Object -TypeName psobject -Property @{'FirstName' = ($_.split(',')[0]).ToString().TrimStart();'LastName' = ($_.split(',')[1]).ToString().TrimStart()})
        }
    else{
        # If entry isn't in a format that we can parse, skip it
        Write-Warning -Message 'Cannot parse entry in user config file, skipping entry...' -WarningAction Continue
        return
        }
    # Check for missing property, skip if true
    if($n.FirstName -ne '' -and $n.LastName -ne ''){
        $NameSeeds += $n
        }
    else{
        Write-Warning -Message 'Skipping name seed entry due to missing information...' -WarningAction Continue
        }
    }

# Get access groups
$AccessGroups = ($Groups | Where-Object{$_.Type -eq 'Access'} | Select -ExpandProperty GroupName)
if($AccessGroups.Count -lt 1){
    throw 'No access groups defined to add users to. Check groups csv file.'
    }
# Get role groups, if -NoRoles specified, skip
if($NoRoles -eq $true){
    $RoleGroups = @()
    }
else{
    $RoleGroups = ($Groups | Where-Object{$_.Type -eq 'Role'} | Select -ExpandProperty GroupName)
    if($RoleGroups.Count -lt 1){
        throw 'No role groups defined to add users to.  Add role groups to config file or specify -NoRoles'
        }
    }


## Generate Usernames

$i = 0
$UserNames = @()
while($i -lt $NumberOfUsers){
    # Get a random first name and a random last name, add together until we have the required number of users
    $f = $NameSeeds[(get-random(0..$NameSeeds.Count)) - 1] | Select-Object -ExpandProperty FirstName
    $l = $NameSeeds[(get-random(0..$NameSeeds.Count)) - 1] | Select-Object -ExpandProperty LastName
    $u = ($f[0] + $l)
    # Truncate long usernames to comply with SamAccountName restriction and allowing us to add
    # a digit at the end if needed.
    if($u.length -gt 21){
        $u = $u[0..19]
        }

    Write-Debug "Generated person: $f $l"
    
    # If we have duplicate usernames, ensure uniqueness by adding a number at the end
    # If this number gets over 9, throw an exception for lack of uniqueness
    $n = 0
    while(($UserNames | Where-Object {$_.UserName -eq $u}) -ne $Null){
        $n++
        $u = ($f[0] + $l + $n)
        if($n -gt 9){
            throw ('Failed to create a unique username, ensure sufficient name seeds')
            }
        }
    Write-Debug "Generated username: $u"
    $UserNames += (New-Object -TypeName psobject -Property @{'FirstName' = $f;'LastName' = $l; 'UserName' = $u})
    $i++
    }


## Create AD Objects

# Create AD Groups
foreach($groupName in ($AccessGroups + $RoleGroups)){
    # Check if the group exists first
    $r = Query-ADObject -Property SamAccountName -SearchValue $groupName -FilterType Group -DomainName $Domain
    # If it exists, check where it is
    # If it's located in the correct location, warn, otherwise throw exception
    if($r -ne $null){
        if($r.distinguishedname -eq ('CN=' + $groupName + ',' + $TargetLocation)){
            Write-Warning "$groupName already exists in the target location, skipping creation..."
            # Continuing loop here since we don't want to try to create a group that already exists.
            continue
            }
        else{
            throw "Group $groupName already exists in a different location. Script will exit with error"
            }
        }
    Write-Verbose "Creating group $GroupName"
    TRY{
        Create-ADGroup -Name $groupName -Description 'Test Lab Generator created group' -Path $TargetLocation -Scope Global -Type Security | Out-Null
        }
    CATCH{
        # Need a terminating error here, since failure to create a group would cause failures when creating users
        throw ("Failed to create $groupName, exception: " + $_.Exception)
        }
    }

# Add each role group to a random number of access groups
Foreach ($RoleGroup in $RoleGroups){
    $groups = Get-RandomAccessGroups -AccessGroups $AccessGroups
    foreach($group in $groups){
        # Inferring the DN from the TargetOU here, this will need to change if support for multiple OUs is added
        Modify-ADGroupMembers -GroupDistinguishedName ('CN=' + $group + ',' + $TargetLocation) `
        -MemberDistinguishedName ('CN=' + $RoleGroup + ',' + $TargetLocation) -Add | Out-Null
        }
    }


# Create Each User, add to a random role group, and add to several random access groups
$PasswordsOut = @()
$UserNames | ForEach-Object{

    <# 
    Not going to bother checking for existing accounts, since they are randomized it should be a small
    chance to have an existing account and failures should not cause further problems like groups.
    #>

    # Create AD User
    Write-Verbose ('Creating user ' + $_.UserName)
    # Generate password
    $p = (New-Password -Length 20)

    TRY{
        Create-ADUser -Name $_.UserName -SamAccountName $_.UserName -FirstName $_.FirstName -LastName $_.LastName -DisplayName ($_.FirstName + ' ' + $_.LastName) `
        -Description 'Test Lab Generator created user' -AccountEnabled -Path $TargetLocation -PasswordNeverExpires -Password $p | Out-Null
        }
    CATCH{
        Write-Error ('Failed to create ' + $_.UserName + ', exception: ' + $_.Exception)
        return
        }
    if($ExportPasswords -eq $true){
        $PasswordsOut += ($_.UserName + ':     ' + $p)
        }
    Clear-Variable p

    # Add to a random role group, unless noroles specified
    if($NoRoles -ne $true){
        Write-Verbose ('Adding ' + $_.UserName + 'to role group')
        # Inferring the DN from the TargetOU here, this will need to change if support for multiple OUs is added
            Modify-ADGroupMembers -GroupDistinguishedName ('CN=' + ($RoleGroups[(Get-Random -Minimum 0 -Maximum ($RoleGroups.Count -1))] + ',' + $TargetLocation)) `
            -MemberDistinguishedName ('CN=' + $_.UserName + ',' + $TargetLocation) -Add | Out-Null
        }
    else{
        Write-Verbose 'NoRoles specified, skipping role group assignment'
        }
    # Add to a random number of access groups unless clean roles specified
    if($CleanRoles -ne $true){
        $groups = Get-RandomAccessGroups -AccessGroups $AccessGroups
        foreach($group in $groups){
            Modify-ADGroupMembers -GroupDistinguishedName ('CN=' + $group + ',' + $TargetLocation)  -MemberDistinguishedName ('CN=' + $_.UserName + ',' + $TargetLocation)  -Add | Out-Null
            }
        }
    else{
        Write-Verbose 'CleanRoles specified, skipping access group assignment for user'
        }
    }

## Wrap-up

# Write our passwords to file if switch is specified
if($ExportPasswords -eq $true){
    $p = ($ScriptDir + '\UserPasswords.txt')
    Write-Output "Writing user passwords to $p" 
    $PasswordsOut | Out-File -FilePath $p
    }

Write-Output 'AD Lab Genernation has completed successfully'