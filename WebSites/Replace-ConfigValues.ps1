# Script Name : Replace-ConfigValues.ps1
# Description : Switching between 2 sets of configs
# Created by  : Rotem Simhi
# Last Update : 2018.08.05
# Version     : 1.0.0.1

param ($ConfigSet = 'Production', $Email = '{From MAIL ADDRESS}', [Array]$Sources = ('C:\windows\inetpub\www'))
# Global Variables:
$global:LogContent = @("Working on $($env:COMPUTERNAME)")
$EventLogSource = $MyInvocation.MyCommand -replace '\.ps1'
$Files = $Sources | ForEach-Object {Get-ChildItem -Path $_ -Filter '*.config' -Recurse}
$Config1 = @{string1 = '';string2 = ''; string3 = ''}
$Config2 = @{string1 = '';string2 = ''; string3 = 'https://f6.rishuybniya.moin.gov.il'}
$Subject = '{0} - {1}' -f $EventLogSource, $env:COMPUTERNAME

$PSDefaultParameterValues = @{
    'Send-MailMessage:SmtpServer' = '{SMTP SERVER IP}';
    'Send-MailMessage:To' = $Email;
    'Send-MailMessage:From' = '{From MAIL ADDRESS}';
    'Send-MailMessage:BodyAsHtml' = $true;
    'Send-MailMessage:Subject' = $Subject
}

function Add-ToLog {
    param($Message)
    $LogLine = '{0} - {1}' -f (Get-Date), $Message
    Write-Verbose $LogLine -Verbose
    $global:LogContent += "<br/> $LogLine"
}

function Replace-ConfigValues
{
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='Medium')]
    Param
    (
        [Alias('config','configFile')]
        [Parameter(Mandatory=$true,
                   Position=0)]
        $ConfigFileLocation,
        $Value1,
        $Value2
    )

    Begin
    {
        $ConfigData = Get-Content -Path $ConfigFileLocation -Encoding UTF8
    }
    Process
    {
        $TempConfigData = $ConfigData.Replace($Value1,$Value2)
    }
    End
    {
        Set-Content -Value $TempConfigData -Path $ConfigFileLocation -Force -Encoding UTF8
        Add-ToLog -Message ('The Value "{0}" was replaced with "{1}" in the file "{2}"' -f $Value1, $Value2, $ConfigFileLocation)
    }
}

function Check-ConfigValues {
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='Medium')]
    Param
    (
        [Parameter(ValueFromPipeline=$true,
                   Mandatory=$true,
                   Position=0)]
        [Alias('config','configFile','configs')]
        [ValidateNotNullOrEmpty()]
        $ConfigFileLocation,

        [ValidateNotNullOrEmpty()]
        $OriginConfig,

        [ValidateNotNullOrEmpty()]
        $NewConfig
    )
    Foreach ($File in $ConfigFileLocation){
        $OriginConfig.GetEnumerator() | Foreach-object { 
            
            Write-Verbose -Message ('Searching {0} for "{1}"'-f $File.FullName, $_.value )
            $Match = Select-String -Path $File.FullName -Pattern $_.value


            if ($Match) {
                Add-ToLog -Message ('The Value "{0}" was found in the file "{1}" in {2} lines' -f ($_.value), ($File.FullName), ($Match.LineNumber).Count)
                
                Replace-ConfigValues -config $File.FullName -Value1 ($_.value) -value2 ($NewConfig[$_.key])
                  
            }else {
                
                #Add-ToLog -Message ('The Value "{0}" was not found in the file "{1}"' -f ($_.value), ($File.FullName))
                
            }
        }
    }
}

Add-ToLog -Message "Replacing configuration values..."

if ($Files){
    if ($ConfigSet -eq 'Production') {
        Check-ConfigValues -ConfigFileLocation $Files -OriginConfig $Config2 -NewConfig $Config1
    
    } elseif ($ConfigSet -eq 'Split') {
        Check-ConfigValues -ConfigFileLocation $Files -OriginConfig $Config1 -NewConfig $Config2
    }
}else{
    Add-ToLog -Message 'Could not find any files...'

}

Add-ToLog -Message 'Finished...'

$Message = ($LogContent -join [System.Environment]::NewLine)
Send-MailMessage -Body $Message

