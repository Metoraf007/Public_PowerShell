
    Get-ChildItem D:\www\police\ -Directory | 
        ForEach-Object { 
            $Directory = Get-item -Path $_.FullName
            Get-ChildItem -Path $Directory -Recurse -File | 
                Measure-Object -Sum Length | 
                    Select-Object @{N='Directory Name';E={$Directory.fullName}},@{N='Number of Files';E={$_.Count}},@{N='Size in MB';E={'{0:N2}' -f [int]($_.Sum/ 1MB) }},@{N='Size in GB';E={'{0}' -f [int]($_.Sum/ 1GB)}} 
        }| ogv