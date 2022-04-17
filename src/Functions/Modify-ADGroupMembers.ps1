# Copyright (c) 2022 Kevin Ott
# Licensed under the MIT License
# See the LICENSE file in the project root for more information.


Function Modify-ADGroupMembers{
    <#
    .SYNOPSIS
        Add or remove a member from an AD Group
    .DESCRIPTION
        This is a function for modifying the membership of an AD group without needing
        the Active Directory Powershell module loaded. The function utilized the DirectoryEntry
        .Net class to either add or remove a single member from an AD group. Uses DistinguishedName 
        for both parameters for simplicity. Function will return a 0 or 1 on success/failure.
    .EXAMPLE
        Modify-ADGroupMembers -GroupDistinguishedName 'CN=Shared Calendar RW,OU=Groups,DC=example,DC=com' -MemberDistinguishedName 'CN=User1,CN=Users,DC=example,DC=com' -Add
        Attempts to add "User1" to the group "Shared Calendar RW".
    .EXAMPLE
	    Modify-ADGroupMembers -GroupDistinguishedName 'CN=Admins RW,OU=Groups,DC=example,DC=com' -MemberDistinguishedName 'CN=User1,CN=Users,DC=example,DC=com' -Remove
        Attempts to remove "User1" from the group "Admins RW".
    .PARAMETER GroupDistinguishedName
        Distinguished name of the group to have it's membership modified.
    .PARAMETER MemberDistinguishedName
        Domain name of the forest where the group resides. If not specified, the current forest will be used.
    .PARAMETER Add
        Specifies that the provided member will be added to the provided group. Cannot be specified with -Remove
    .PARAMETER Remove
        Specifies that the provided member will be removed from the provided group. Cannot be specified with -Add
    .NOTES
        Filename: Function Modify-ADGroupMembers.ps1
        Version: 1.0
        Date: 7/30/2018
        Author: Kevin Ott
    .LINK
        https://github.com/KevOtt/AD-Tools
    #>

Param(
    [string]$GroupDistinguishedName,
    [string]$MemberDistinguishedName,
    [Parameter(ParameterSetName='Add')]
    [switch]$Add,
    [Parameter(ParameterSetName='Remove')]
    [switch]$Remove
    )

    # Create the directory entry object
    $directoryEntry = New-Object ([System.DirectoryServices.DirectoryEntry]) -ArgumentList ('LDAP://' + $GroupDistinguishedName) -ErrorAction Stop

    # Add membership
    if($Add -eq $true){
        # Check if already a member
        if($directoryEntry.Properties['Member'] -contains $MemberDistinguishedName){
            Write-Error -Category InvalidOperation -Exception 'Object is already a group member' -Message 'User is already a member of the specified group'
            return 1
            }
        Write-Verbose ("Adding $MemberDistinguishedName to group $GroupDistinguishedName")
        $directoryEntry.Properties["member"].Add($MemberDistinguishedName) | Out-Null
        }

    # Remove membership
    if($Remove -eq $true){
        # Check if not a member
        if($directoryEntry.Properties['Member'] -notcontains $MemberDistinguishedName){
            Write-Error -Category InvalidOperation -Exception 'Object is not a group member' -Message 'User is not a member of the specified group'
            return 1
        }
        Write-Verbose ("Removing $MemberDistinguishedName from group $GroupDistinguishedName")
        $directoryEntry.Properties["member"].Remove($MemberDistinguishedName) | Out-Null
        }

    # Write changes to AD
    TRY{
        $directoryEntry.CommitChanges()
        }
    CATCH{
        Write-Error $_.exception
        return 1
        }
    Write-Verbose 'Modification completed successfully.'
    return 0
    }