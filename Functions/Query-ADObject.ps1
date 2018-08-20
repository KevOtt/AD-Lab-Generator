# Copyright (c) 2018 Kevin Ott
# Licensed under the MIT License
# See the LICENSE file in the project root for more information.


Function Query-ADObject{
    <#
    .SYNOPSIS
        Returns details on one or more AD Objects.
    .DESCRIPTION
        This is a function for returning details on AD objects without needing
        the Active Directory Powershell module installed. The function is essentially a wrapper
        for running an LDAP query with the .Net Directory searcher. Assumes that the executing account
        has appropriate read access to the domain. Depending on whether one or more objects
        is returned, the function will return either a ResultPropertyCollection or an
        array of ResultPropertyCollection. Use ReturnOne switch to only return the former
        for the first AD Object found. If no search property is specified, CN is the assumed
        search property.
    .EXAMPLE
        Query-ADObject -SearchValue 'User1' -FilterType User -DomainName 'example.com'
        Searched for any AD user object for which the property CN is "User1" in domain "example.com"
    .EXAMPLE
	    Query-ADObject -Property 'Name' -SearchValue 'T*' -FilterType User -DomainName 'example.com'
        Searches for any AD object for which the property Name starts with "T".
    .EXAMPLE
	    Query-ADObject -Property DNSHostName -SearchValue 'C*' -FilterType Computer -DomainName 'klab.local' -ReturnOne
        Searches for any AD computer object for which the property DNSHostName starts with "C", and will return only the
        first object found, due to the ReturnOne switch.
    .PARAMETER Property
        The AD Object property on which to search, e.g. Name, DNSHostName, etc. If not specified,
        assume CN as the search property.
    .PARAMETER SearchValue
        The value to search for in AD. LDAP search query wildcards can be used.
    .PARAMETER FilterType
        Filter on a specific type of object. Valid values are User, Computer, Group, OrganizationalUnit,
        and Container.
    .PARAMETER DomainName
        The full name of the domain where the initial object resides.
    .PARAMTER ReturnOne
        Returns a ResultPropertyCollection for only the first AD object found that matches the search parameters.
    .NOTES
        Filename: Function Query-ADObject.ps1
        Version: 1.0
        Date: 7/11/2018
        Author: Kevin Ott
    .LINK
    https://github.com/KevOtt/AD-Tools
    #>
    
    param(
        [string]$Property,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$SearchValue,
        [ValidateSet('User','Computer','Group','OrganizationalUnit','Container')] 
        [string]$FilterType,
        [Parameter(Mandatory = $true)]
        [string]$DomainName,
        [switch]$ReturnOne
        )

        # If no property specified, assume 'cn'
        if($Property -eq ''){
            $Property = 'cn'
            }

        $DirectorySearcher = New-Object ([System.DirectoryServices.DirectorySearcher])
        
        # Set our filter to the specified object attribute, check for specified object type
        $Filter = $UserQuery = ($Property + '=' + $SearchValue)
        if($FilterType -ne ''){
            $Filter = "(&(objectClass=$FilterType)($UserQuery))"
            }

        $DirectorySearcher.Filter = $Filter
        # Convert domain from fqdn format to ldap query format and set as search root
        $DirectorySearcher.SearchRoot =  ('LDAP://' + (@(ForEach($s in ($DomainName.Split('.'))) {('DC=' + $s)}) -join ','))
        
        # Return first result object found if ReturnOne switch true
        if($ReturnOne -eq $true){
            return ($DirectorySearcher.FindOne().Properties)
            }

        # Return all objects
        return @($DirectorySearcher.FindAll().Properties)
}
