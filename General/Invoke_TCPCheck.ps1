$TargetIP = '{TARGET IP ADDRESS}'
$TcpTest = Test-NetConnection -ComputerName $TargetIP -port 25 | Select-Object -ExpandProperty TcpTestSucceeded
while ($TcpTest){
    #$Invoke = Invoke-WebRequest -uri 'http://orchestrator:81/orchestrator2012/orchestrator.svc/' -Credential $cred | select -ExpandProperty statuscode
    $TcpTest = Test-NetConnection -ComputerName $TargetIP -port 25 | Select-Object -ExpandProperty TcpTestSucceeded
   
    if ($TcpTest){
       Write-Host ('{0:HH:mm} -- TCP Test Connection: {2}' -f (get-date), $Invoke, $TcpTest) -BackgroundColor Blue
    }else{
       Write-Host ('{0:HH:mm} -- TCP Test Connection: {2}' -f (get-date), $Invoke, $TcpTest) -BackgroundColor Red
    }
    '{0:HH:mm:ss} -- TCP Test Connection: {2}' -f (get-date), $Invoke, $TcpTest | Out-File -FilePath d:\temp\Orch_Connection.txt -Force -Append
    Start-Sleep -Seconds 5
}