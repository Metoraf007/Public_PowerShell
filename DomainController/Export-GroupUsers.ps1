param ($Group)
function Export-GroupUsers ($GroupName) {
    Get-ADGroup -Filter {Name -like "*$GroupName*"} | 
        ForEach-Object {
            $List = 'e:\temp\{0}.txt' -f $_.name
            New-Item -Path $list -ItemType file -Force

            Get-ADGroupMember -Identity $_ | 
                Select-Object Name, SamAccountName | 
                    Out-File -FilePath $List -Append
        }
}

export-GroupUsers -GroupName $Group