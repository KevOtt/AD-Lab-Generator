# Copyright (c) 2022 Kevin Ott
# Licensed under the MIT License
# See the LICENSE file in the project root for more information.

Function New-Password{
    <#
    .SYNOPSIS
        Generates a random string
    .DESCRIPTION
        This is a function for generating a random crypto-safe string for use
        as a password or anything else requing a random ascii string.
    .PARAMETER Length
        Requested length of password, from 1 to 100 characters.
    .NOTES
        Filename: Function New-Password.ps1
        Version: 1.0
        Date: 8/19/2018
        Author: Kevin Ott
    .LINK
        https://github.com/KevOtt
    #>
        
    param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(1,100)]
        [int]$Length
        )

    [string]$password = $null
    $i = 1
    # Create instance of crypto random provider to get secure random strings
    $rng = New-Object ([System.Security.Cryptography.RNGCryptoServiceProvider]::new()) -ErrorAction Stop
    while($i -le $Length){
        do{
            $r = (New-Object byte[] 1)
            $rng.GetBytes($r)
            [int]$n = $r[0]
            }
            # Filter out unicode characters, quotes and '#'
        until($n -gt 32 -and ($n -lt 127) -and ($n -ne 34 -and $n -and 39 -and $n -and 96 -and $n -ne 35))
        $password += [char]$n
        $i++
        }
    return $password
    }