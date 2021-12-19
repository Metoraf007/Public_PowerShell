# Script Name : Invoke-SqlScripts.ps1
# Description : Runs multipale sql scripts on a given SQL server 
# Created by  : Rotem Simhi
# Last Update : 2018.01.14
# Version     : 1.0.0

param ($SqlFolder, $Email, $DataSource = 'Localhost', $DataBase = 'ADBA')

function Invoke-SqlScripts {
<#
.Synopsis
   Runs multipale sql scripts on a given SQL server and sends a mail with the response
.EXAMPLE
   Invoke-SqlScripts -SqlFolder 'D:\temp\SQLScripts' -Mail 'Test@Domain.org' -DataSource 'Databate Instance IP' -Database 'Orchestrator_DB'
.INPUTS
   $SqlFolder - Path to the sql-scripts' location
   $Mail - Outgoing mail address
   $DataSource - The SQL server's IP Address
   $Database - The SQL database name
.OUTPUTS
   String
#>
    [CmdletBinding(SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  ConfirmImpact='Medium')]
    [OutputType([String])]
    param (
    [Parameter(Mandatory=$true, 
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true, 
               ValueFromRemainingArguments=$false, 
               Position=0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({(Test-Path -path $_)})]
    [Alias('Folder','FileFolder')]
    [Array]$SqlFolder, 
    [Alias('EMail','EMailAddress')]
    [string]$Mail = 'Test@Domain.org',
    [Alias('DBServer','Server')]
    [string]$DataSource = 'Localhost',
    [Alias('DBName','CatalogName','Catalog')]
    [string]$Database = 'ADBA'
    )

    Begin {
        [regex]$RX = '\[(.*?)\]'

        $PSDefaultParameterValues = @{
            'Send-MailMessage:SmtpServer' = '{SMTP SERVER IP}}';
            'Send-MailMessage:To'         = $Mail;
            'Send-MailMessage:cc'         = '{CC MAIL ADDRESS}';
            'Send-MailMessage:From'       = '{From MAIL ADDRESS}';
    }
        $SqlFiles = $SqlFolder | ForEach-Object { Get-ChildItem -Path $_ -Filter "*.sql" | Sort-Object -Property Name}
    }

    Process {
    
        Foreach ($File in $SqlFiles){

            
            [string]$SQLCommand = (Get-Content -Path $File.FullName -raw -Encoding UTF8 ) -replace '(?m)^\s*\r?\n'
            if ($SQLCommand -match $rx) { 
                $Database = $Matches[1]
            }
            if (($SQLCommand.Contains('ALTER')) -or ($SQLCommand.Contains('CREATE')) ){
                while (! (($SQLCommand.StartsWith('ALTER')) -or ($SQLCommand.StartsWith('CREATE')) )) {
                    
                    $SQLCommand = $SQLCommand.Trimstart($SQLCommand[0])
                    #$SQLCommand = $SQLCommand -creplace 'GO'
                }
            }
            
            $ConnectionSrting = "Server=$DataSource; " + "Integrated Security=SSPI; " + "Initial Catalog=$Database"
            $Connection = New-Object System.Data.SQLClient.SQLConnection($ConnectionSrting)
            $Connection.Open()

            $Command = New-Object System.Data.SQLClient.SQLCommand($SQLCommand,$Connection)
            $adapter = New-Object System.Data.SQLClient.SQLDataAdapter $Command
            $dataset = New-Object System.Data.dataset
            try
            {
               $MailSubject = 'Success - Sql Query Script: {0}' -f ($File.Name)
               $adapter.Fill($dataset)  | Out-Null -ErrorAction SilentlyContinue
               $Body = $dataset.Tables.rows |  ForEach-Object {$_ ; '<br>'}  | Out-String
            }
            catch 
            {
                $MailSubject = 'Failed - Sql Query Script: {0}' -f ($File.Name)
                $Body = $Error[0].Exception | Out-String
            }

            $Connection.Close()
            
            if ((-not $Body) -or ($Body[0] -like '<')){
                $Body = 'The SQL Script did not create any output data'
            }

            Send-MailMessage -Body $Body -Subject $MailSubject -Encoding utf8 -BodyAsHtml
            
        }
    }
    End {
        
    }
}

# $SqlFolder = 'D:\temp\SQLScripts'

Invoke-SqlScripts -SqlFolder $SqlFolder -Mail $Email -DataSource $DataSource -Database $DataBase

