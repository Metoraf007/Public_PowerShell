Import-Module -Name *ActiveDirectory*
Get-ADUser -Filter 'SamAccountName -like "g*"' | 
    select-object -ExpandProperty SamAccountName | 
        ForEach-Object {

        $NewName = $_.Substring(0,1).toupper() + $_.Substring(1).tolower()
        $_ | Set-ADUser -SamAccountName $NewName
        Write-verbose ("SamAccountName has been changed from: " + $_ +" to: " + $NewName) -Verbose

    }