# Script Name : Upload-SSRSReports.ps1
# Description : Publish a SSRS Report File to a SSRS Report Server
# Created by  : Rotem Simhi
# Last Update : 2019.07.17
# Version     : 1.0.0.1

Param (
    $ReportFolder,
    $reportServer,
    $uploadPath,
    $targetDatasourceRef,
    $Mail
)

$reportServerURI = 'http://{0}/reportserver/ReportService2010.asmx?wsdl' -f $reportServer
# Event log entry defenitions and creation function
. D:\Scripts\Add-ToLog.ps1
$EventLogSource = $MyInvocation.MyCommand -replace '\.ps1'
$global:LogContent = @($EventLogSource)
New-EventLog -LogName Application -Source $EventLogSource -ErrorAction SilentlyContinue

# E-Mail Params
$PSDefaultParameterValues = @{
        'Send-MailMessage:SmtpServer' = '{SMTP SERVER IP}}';
        'Send-MailMessage:To'         = $Mail;
        'Send-MailMessage:cc'         = '{CC MAIL ADDRESS}';
        'Send-MailMessage:From'       = '{From MAIL ADDRESS}';
        'Send-MailMessage:Subject'    = 'Publish SSRS Report: {0}' -f $reportServer;
}
function Upload-SSRSReports {
Param (
    $ReportFolder,
    $reportServerURI,
    $uploadPath,
    $targetDatasourceRef,
    $Mail
)
    Begin {
    # Create a Report Service Connection
        Add-ToLog -Message "Create a Report Service Connection"
        
        $RSConnection = New-WebServiceProxy -Uri $reportServerURI -UseDefaultCredential -Namespace "SSRS"
        Add-ToLog -Message "Connected to $reportServerURI"

        $CatalogItems = $RSConnection.ListChildren("/", $true)
        $CatalogFolder = $CatalogItems | Where-Object {$_.TypeName -eq 'Folder' -and $_.Path -eq $uploadPath }
        
        $RdlFiles = Get-ChildItem -Path $ReportFolder -Filter "*.rdl"
    }
    Process
    {
        $Warnings = $null
        foreach ($RdlFile in $RdlFiles){
            $ReportName = $RdlFile.BaseName
            $bytes = [System.IO.File]::ReadAllBytes($RdlFile.FullName)

            Add-ToLog -Message "Uploading $ReportName"
            $Report = $RSConnection.CreateCatalogItem(
                "Report",      # Catalog item type
                $ReportName,   # Report Name
                $uploadPath,   # Destination Path
                $true,         # Overwrite existing report
                $bytes,        # .rdl file content
                $null,         # Properties
                [ref]$Warnings      # Warnings while uploading
                )

            $Warnings | ForEach-Object {
                Add-ToLog ('<p style="color:Orange;">Warning: {0} </p>' -f $_.Message)
            }
            
            Add-ToLog -Message "Setting Item Data Source"
            try
            {
                $RefrencedDataSourceName = (@($RSConnection.GetItemReferences($Report.Path, "DataSource")))[0].Name
            
                $DataSource = New-Object SSRS.DataSource
                
                # Name as used when designing the Report
                $DataSource.Name = $RefrencedDataSourceName
                $DataSource.Item = New-Object SSRS.DataSourceReference
                
                # Path to the share data source as it is deployed here.
                $DataSource.Item.Reference = $targetDatasourceRef
                $RSConnection.SetItemDataSources($Report.Path, [SSRS.DataSource[]]$DataSource)
            }
            catch
            {
                Add-ToLog -Message "<p style=`"color:Tomato;`">$(($Error)[0]).exception </p>"
            }

        }
    }
    End
    {
        Add-ToLog -Message "Finished..."
        Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -EventId 0 -Message ($LogContent -join [System.Environment]::NewLine)
        Send-MailMessage -Body ($LogContent -join '</br>') -BodyAsHtml
    }

}

Upload-SSRSReports -ReportFolder $ReportFolder -reportServerURI $reportServerURI -uploadPath $uploadPath -targetDatasourceRef $targetDatasourceRef -Mail $Mail