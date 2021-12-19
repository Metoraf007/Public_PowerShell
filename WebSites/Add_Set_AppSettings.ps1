# Add / Change AppSetting values in the Web Config
# Load params from user
# Last Change : 04.09.2019
param([Parameter(Mandatory=$True)]$Mail,[Parameter(Mandatory=$True)]$Site,[Parameter(Mandatory=$True)]$CSVFile)
Import-Module -name *web*

# E-Mail Params
$PSDefaultParameterValues = @{
    'Send-MailMessage:SmtpServer' = '{SMTP SERVER IP}}';
    'Send-MailMessage:To'         = $Mail;
    'Send-MailMessage:cc'         = '{CC MAIL ADDRESS}';
    'Send-MailMessage:From'       = '{From MAIL ADDRESS}';
}

function Get-SitePath {
param (

    $SiteName = ''
)

    $Site = Get-Website $SiteName
    $webApplication = Get-WebApplication $SiteName 
    $WebRoot = 'MACHINE/WEBROOT/APPHOST/'
    
    $IISSites = @{}
    if ($Site) {
        $SitePath = '{0}{1}' -f $WebRoot, $SiteName
    }elseif ($webApplication) {
        $Site = $webApplication | Select-Object @{N='PSPath';E={$_.itemXpath.split("'")[1]}}
        $SitePath = '{0}{1}/{2}' -f $WebRoot, $Site.pspath, $SiteName
    }
    return $SitePath
}

# Create the function
function appSetting($Mail,$Site,$CSVFile) {

    # Import new appSetting values to hash table
    $NewappSettings = @{}
    Import-Csv -Path $CSVFile | ForEach-Object { $NewappSettings.Add($_.Name, $_.Value)}

    #$myWarnings.Clear()
    $SitePath = Get-SitePath -SiteName $Site
    $currentAppSettings = @{}
    if (-not ($SitePath) ) {
        $Body = 'Site Does not exists'
        Send-MailMessage -Subject "Configuration change attempt was made in $hostname/$Site web application" -BodyAsHtml $Body
        exit 3
    }
    
    # Fill the $currentAppSettings hash table with current site configuration
    Get-WebConfigurationProperty -PSPath $SitePath  -Filter "appSettings/add" -Name "." | ForEach-Object { $currentAppSettings.Add($_.Key, $_.Value)}

    # Check if key exist, if it does; change it, if it does not; add it.
    $NewappSettings.GetEnumerator() | ForEach-Object {
        if(-not $currentAppSettings.ContainsKey($_.Name)) {
            Add-WebConfigurationProperty -PSPath $SitePath -Filter "appSettings" -Name "." -value @{key=$_.Key;value=$_.Value}

        } else {
            Set-WebConfigurationProperty -PSPath $SitePath -filter "appSettings/add[@key='$($_.Key)']" -name "value" -value $_.Value -WarningVariable +myWarnings -WarningAction SilentlyContinue

        }
    }

    # Export Warning messages to user
    $Hostname = hostname
    $Body = $myWarnings | select -Property Message
        if (!($Body -eq $Null)){
        $Body = "Error: Cannot set key value, please make sure the key you have inserted is in the same case as the existing appSetting key."
        Send-MailMessage -Subject "Configuration change attempt was made in $hostname/$Site web application" -BodyAsHtml $Body
        } else {
        $Body = 'Configuration File Attached'
        $Config = Get-WebConfigFile -PSPath $SitePath | Select-Object -ExpandProperty fullname 
        Send-MailMessage -Subject "Configuration change attempt was made in $hostname/$Site web application" -BodyAsHtml $Body  -Attachments $Config
        }
}
# Run the function
appSetting -Mail $Mail -Site $Site -CSVFile $CSVFile