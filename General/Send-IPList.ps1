$CSV = import-csv -Path D:\temp\ip.csv

foreach ($ip in $csv) {

        $ping = Test-Connection -ComputerName $ip.ipaddress -Count 1 -Quiet
        if ($ping -eq $true) {
            $ip.ping = $true
            $ip.arp = $True
            $ip.Clear = $False

        }else {
            $ip.ping = $False

            $arpIPs = arp -a | Select-String -Pattern 192.168. | % {$_.tostring().trim().Split(" ")[0]}

            if ($arpIPs.Contains($ip.ipaddress)) {
                
                $ip.arp = $True
                $ip.Clear = $False
            }else {
            
                $ip.arp = $False
                $ip.Clear = $True
             }
         }
         $ip | export-csv -Path d:\temp\178.csv -Append -NoTypeInformation -force
}
Send-MailMessage -Attachments d:\temp\178.csv -SmtpServer 192.168.180.88 -from Automation@cio.gov.il -to hosting@cio.gov.il -Subject "178 Network"