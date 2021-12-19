<#
    Name        : Run-OSqlScripts.ps1
    Description : Run a bulk of sql scripts using SQLCMD, output is sent by E-Mail
    Last Update : 2020/02/20 08:10
    Notes       : For Any Instance
    Version     : 1.0.2.0
    Owner       : Rotem Simhi

#>
param ($Mail = 'YOURMAIN@Domain.org', $ScriptPath = 'C:\Temp\DBScripts', $SqlServer = '{SQL SERVER ADDRESS}}')
 
$PSDefaultParameterValues = @{
            'Send-MailMessage:SmtpServer' = '{SMTP SERVER IP}}';
            'Send-MailMessage:To'         = $Mail;
            'Send-MailMessage:cc'         = '{CC MAIL ADDRESS}';
            'Send-MailMessage:From'       = '{From MAIL ADDRESS}';
    }

$MailSubject = '{0} - Sql Query Script: {1}' 
$ScriptFilter = '*.sql'

Get-ChildItem -Filter $ScriptFilter -Path $ScriptPath | 
    Select-Object -ExpandProperty FullName | Sort-Object | 
        ForEach-Object {

            $ScriptName = Split-Path -Path "$_" -Leaf
            #write-host "Script Name: $ScriptName" -ForegroundColor Cyan
            $OutputFile = (Split-Path -Path "$_" -Parent) + "\" + ($ScriptName -replace '.sql', '.txt')
            $OutCSVFile = (Split-Path -Path "$_" -Parent) + "\" + ($ScriptName -replace '.sql', '.csv')
            $ScriptOutput = sqlcmd.exe -S "$SqlServer" -i "$_" -t 270 -E -b -W -I -s "|" -o $OutputFile
            #write-host "Osql Exit Code: $LASTEXITCODE" -ForegroundColor Cyan
            
            if ($LASTEXITCODE -eq 0) { 
                $Status = 'Success'
            } else { 
                $Status = 'Failed'
            }
            $ScriptOutput = Get-Content $OutputFile
            if ($ScriptOutput) {
                Get-Content $OutputFile -Force | Select-Object -Skip 1 | ConvertFrom-Csv -Delimiter "|" |  Export-Csv $OutCSVFile -Force -NoTypeInformation -Encoding UTF8
                $ScriptOutput = $ScriptOutput | ForEach-Object { if($_ -imatch 'Error') { "<font color='tomato'>{0}</font>" -f $_} else {$_} }
                $ScriptOutput = $ScriptOutput -join '<br/>'
            } else {
                $ScriptOutput = 'No Output'
            }
            Send-MailMessage -Body $ScriptOutput -Subject ($MailSubject -f $Status, $ScriptName) -Encoding utf8 -Attachments $OutCSVFile -BodyAsHtml
        }