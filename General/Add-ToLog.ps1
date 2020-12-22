# Script Name : Out-Log.ps1
# Description : Publish an Event Log
# Created by  : Rotem Simhi
# Last Update : 2019.07.16
# Version     : 1.0.0.0


function Add-ToLog {
    param($Message)
    $LogLine = '{0} - {1}' -f (Get-Date), $Message
    Write-Verbose $LogLine -Verbose
    $global:LogContent += $LogLine

}