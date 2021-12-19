# Use in case of Windows Server 2008
$CSV = Import-Csv -Path 'C:\temp\ipList.csv'
$ExportFile = 'C:\temp\Network.csv'
$AddressPatten = '192.168.'

foreach ($ip in $CSV) {

        $ping = Test-Connection -ComputerName $ip.ipaddress -Count 1 -Quiet
        if ($ping -eq $true) {
            $ip.ping = $true
            $ip.arp = $True
            $ip.Clear = $False

        }else {
            $ip.ping = $False

            $arpIPs = arp -a | Select-String -Pattern $AddressPatten | Where-Object {$_.tostring().trim().Split(" ")[0]}

            if ($arpIPs.Contains($ip.ipaddress)) {
                
                $ip.arp = $True
                $ip.Clear = $False
            }else {
            
                $ip.arp = $False
                $ip.Clear = $True
             }
         }
         $ip | export-csv -Path $ExportFile -Append -NoTypeInformation -force
}

Send-MailMessage -Attachments $ExportFile -SmtpServer 'SMTP.SERVER.COM' -from 'from@Mail.com' -to 'ToMail@Mail.com' -Subject "Network"
