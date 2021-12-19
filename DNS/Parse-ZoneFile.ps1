# Name          : Parse-ZoneFile.ps1
# Last Modified : 28.12.2020
# Version       : 1.0.0.1
# Authors       : Rotem Simhi & Elad Naim

$sourcePath = ''
$outputPath = '\Zone.csv'

foreach ($file in (get-childitem $sourcePath | where-object {($_.extension -ne ".csv") -and ($_.extension -ne ".txt") -and ($_.extension -ne ".ps1") } )){
    
    $FilePath = $file.Fullname
    $FileName = $file.name
    $zone_file = Get-Content $FilePath
    $origin = $FileName

    foreach ($line in $zone_file)
    {
        $line = $line.Trim()
        $break_line = ($line -replace '\s+|\t+', "," | where-object {($_ -notlike "*;*") -and ($_ -ne $null)} ) -split ','

        if ($break_line -contains '$ORIGIN'){
            $origin = $break_line[1]
        }
        if ($break_line[0] -like '*.'){
            $dot = $true
        }else{
            $dot = $false
        }
        foreach ($break in $break_line){
            if ($break -eq 'IN'){
                $break_line = $break_line | where-object {$_ -ne $break}
            }
            if ($break -eq '@'){
                $break_line = $break_line | where-object {$_ -ne $break}
                $Shtrudel = $true
            }
            if ($break_line.count -gt 2){
                $key = $break_line[0]
            }
            if (($break -eq "A") -or ($break -eq "AAAA") -or ($break -eq "CNAME") ){
                if ($Shtrudel){
                    $first_line = '{1},{3},{2}' -f $key, $origin, $break_line[-1], $break
                    $first_line | Select-Object @{N='Record';E={$origin}},@{N='Type';E={$break}},@{N='Address';E={$break_line[-1]}},@{N='Zone';E={$FileName}} | export-csv -path $outputPath -notype -force -append
                    $Shtrudel = $false
                }else{
                    if ($dot){
                        $first_line = '{0},{3},{2}' -f $key, $origin, $break_line[-1], $break
                        #write-host $first_line
                        $first_line | Select-Object @{N='Record';E={$key}},@{N='Type';E={$break}},@{N='Address';E={$break_line[-1]}},@{N='Zone';E={$FileName}}  | export-csv -path $outputPath -notype -force -append
                        $dot = $false
                    }else{
                        $first_line = '{0}.{1},{3},{2}' -f $key, $origin, $break_line[-1], $break
                        $first_line | Select-Object @{N='Record';E={"$key.$origin"}},@{N='Type';E={$break}},@{N='Address';E={$break_line[-1]}},@{N='Zone';E={$FileName}}  | export-csv -path $outputPath -notype -force -append
                    }
                }
            }
        }
    }
}