function Test-PendingReboot {

$Test1 = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ea Ignore
$Test2 = Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ea Ignore
$test3 = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -name PendingFileRenameOperations -ea Ignore
$Util = ([wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities").DetermineIfRebootPending()
$Test4 = $Util.rebootPending
if ($Test1 -or $Test2 -or $Test3 -or ($Util -ne $null -and $Test4) ) {Restart-Computer -Confirm}else{Write-Host 'No Reboot Required' -ForegroundColor Green}
}

Test-PendingReboot