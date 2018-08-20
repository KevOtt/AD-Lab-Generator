# Copyright (c) 2018 Kevin Ott
# Licensed under the MIT License
# See the LICENSE file in the project root for more information.


Function Create-ADGroup{
    <#
    .SYNOPSIS
        Creates an Active Directory group.
    .DESCRIPTION
        This is a function for creating a new AD group without needing the Active Directory Powershell 
        module loaded by utilizing the DirectoryEntry .Net class. Name and group scope and type need to be specified.
        Will create the group in the root of the current domain by default, specify a DN of a specific OU or CN instead.
    .EXAMPLE
        Create-ADGroup -Name Group1 -Path 'CN=Users,DC=example,DC=com' -Scope Global -Type Security
        Creates a Global security group called "Group1" in the users container.
    .EXAMPLE
        Create-ADGroup -Name Admins SamAccountName "ServerAdmins" -Description 'Server administrators' Group -Scope universal -Type Security
        Creates a Universal security group called "Admins", with SamAccount name of ServerAdmins in the domain root.
    .PARAMETER Name
        Name or "CN" attribute of the group to create. Alias of "CN".
    .PARAMETER SamAccountName
        SamAccountName attribute of the group to create. If not specified, we will use
        the same value as "CN" for "SamAccountName"
    .PARAMETER Description
        Description to be set on the group. Can be left blank
    .PARAMETER Path
        AD location to create the new group. The path must be specified as a DistinguishedName
        value of an Organizational Unit or Container. If left blank, the group will be created in the
        users container of the current domain.
    .PARAMETER Scope
        Scope of the group, valid values are Global, Universal, and Domain Local.
    .PARAMETER Type
        Type of group to create, valid values are Security and Distribution.
    .NOTES
        Filename: Function Create-ADGroup.ps1
        Version: 1.0
        Date: 7/30/2018
        Author: Kevin Ott
    .LINK
        https://github.com/KevOtt/AD-Tools
    #>
    
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [Alias('CN')]
        [string]$Name,
        [string]$SamAccountName,
        [string]$Description,
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Global','Universal','DomainLocal')]
        $Scope,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Security','Distribution')]
        $Type
    )
    
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
        $r = $directorySearcher.FindOne()
        if($r -eq $null -or ($r.Properties.objectclass -notcontains 'container' -and $r.Properties.objectclass -notcontains 'OrganizationalUnit')){
            throw 'Provided Path cannot be found or is not a Container or Organizational Unit'
            }

        $pathArgument = ('LDAP://' + $Path)
        }
    $directoryEntry = New-Object ([System.DirectoryServices.DirectoryEntry]) -ArgumentList $pathArgument -ErrorAction Stop
    # If we don't have a valid DirectoryEntry object, throw exception
    if($directoryEntry -eq $null){
        throw 'Could not find directory or directory path. Specify a valid DN'
        }

    # Determine the grouptype value
    <#
    https://docs.microsoft.com/en-us/windows/desktop/adschema/a-grouptype
    1 (0x00000001)	Specifies a group that is created by the system.
    2 (0x00000002)	Specifies a group with global scope.
    4 (0x00000004)	Specifies a group with domain local scope.
    8 (0x00000008)	Specifies a group with universal scope.
    16 (0x00000010)	Specifies an APP_BASIC group for Windows Server Authorization Manager.
    32 (0x00000020)	Specifies an APP_QUERY group for Windows Server Authorization Manager.
    2147483648 (0x80000000)	Specifies a security group. If this flag is not set, then the group is a distribution group.
    #>

    if($Type -eq 'Security'){
        $tb = 0x80000000
        }
    if($Scope -eq 'Global'){
        $sb = 0x00000002
        }
    elseif($Scope -eq 'DomainLocal'){
        $sb = 0x00000004
        }
    else{$sb = 0x00000008}

    $groupType = $tb -bor $sb

    # Create new group
    $newGroup = $directoryEntry.Children.Add("cn=$Name",'group')
    $newGroup.Properties['grouptype'].Value = $groupType
    if($SamAccountName -eq ''){
        $SamAccountName = $Name
        }
    $newGroup.Properties['SamAccountName'].Value = $SamAccountName
    if($Description -ne ''){
        $newGroup.Properties['Description'].Value = $Description
        }

    # Commit changes
    TRY{
        $newGroup.CommitChanges()
       }
    CATCH{
        Write-Error -Exception $_.Exception
        return 1
        }

    return 0
}



