# Copyright (c) 2022 Kevin Ott
# Licensed under the MIT License
# See the LICENSE file in the project root for more information.

Function Get-RandomAccessGroups {
        <#
    .SYNOPSIS
        Gets a random number of groups from a list of groups.
    .PARAMETER AccessGroups
        Input list of groups
    .NOTES
        Filename: Function New-Password.ps1
        Version: 1.0
        Date: 8/19/2018
        Author: Kevin Ott
    .LINK
        https://github.com/KevOtt
    #>

    Param(
        [Parameter(Mandatory=$true)]
        $AccessGroups
        )

    $i = Get-Random -Minimum 1 -Maximum ($AccessGroups.Count - 1)
    $groups = @()
    $n = 0
    while($n -ne $i){
        $g = Get-Random -Minimum 1 -Maximum ($AccessGroups.Count - 1)
        if($AccessGroups[$g] -notin $groups){
            $groups += $AccessGroups[$g]
            $n++
            } 

        }
    return $groups
    }