# Script Name  : Set-IISServer.ps1
# Date         : 24.12.2020
# Author       : Rotem Simhi
# Version      : 1.0.0.2

#region Configurable variables:

$WebsiteLogsFolder = 'D:\IISLogs' # Insert location for exported IIS log files here
$WinSxSFolder = 'D:\sources\sxs' # Insert location for windows installation disk

#endregion


#region Install IIS:

$ComponentsToInstall = @(
    'NET-Framework-Features',
    'NET-Framework-45-Features',
    'Web-Default-Doc',
    'Web-Http-Errors',
    'Web-Static-Content',
    'Web-Http-Redirect',
    'Web-Http-Logging',
    'Web-Log-Libraries',
    'Web-Request-Monitor',
    'Web-Http-Tracing',
    'Web-Stat-Compression',
    'Web-Dyn-Compression',
    'Web-Filtering',
    'Web-CertProvider',
    'Web-IP-Security',
    'Web-Url-Auth',
    'Web-Windows-Auth',
    'Web-Net-Ext',
    'Web-Net-Ext45',
    'Web-AppInit',
    'Web-Asp-Net',
    'Web-Asp-Net45',
    'Web-ISAPI-Ext',
    'Web-ISAPI-Filter',
    'Web-Mgmt-Console',
    'Web-Scripting-Tools',
    'Web-Mgmt-Service')
Add-WindowsFeature -Name $ComponentsToInstall -IncludeManagementTools -Source $WinSxSFolder

#endregion


#region Configure IIS and ASP.NET:

# ApplicationPools settings:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults -Name queueLength -Value 5000
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/processModel -Name idleTimeout -Value '00:00:00'
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/recycling -Name logEventOnRecycle -Value 'Time,Requests,Schedule,Memory,IsapiUnhealthy,OnDemand,ConfigChange,PrivateMemory'
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/recycling/periodicRestart -Name time -Value '00:00:00'
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/recycling/periodicRestart/schedule -Name . -Value @{value='04:00:00'}


# Website Logging settings:
New-Item -Path $WebsiteLogsFolder -ItemType Directory -Force | Out-Null
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/sites/siteDefaults/logFile -Name logExtFileFlags -Value 'Date,Time,ClientIP,UserName,SiteName,ComputerName,ServerIP,Method,UriStem,UriQuery,HttpStatus,Win32Status,BytesSent,BytesRecv,TimeTaken,ServerPort,Cookie,Referer,ProtocolVersion,Host,HttpSubStatus'
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/sites/siteDefaults/logFile -Name directory -Value $WebsiteLogsFolder
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/sites/siteDefaults/logFile/customFields -Name "." -value @{logFieldName='X-Forwarded-For';sourceName='X-Forwarded-For';sourceType='RequestHeader'}


# Windows Authentication settings:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/security/authentication/windowsAuthentication -Name authPersistNonNTLM -Value $true
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/security/authentication/windowsAuthentication -Name useKernelMode -Value $true
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/security/authentication/windowsAuthentication -Name useAppPoolCredentials -Value $true


# HttpCompression settings:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/httpCompression -Name minFileSizeForComp -Value 512
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/httpCompression -Name staticCompressionEnableCpuUsage -Value 65
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/httpCompression -Name dynamicCompressionEnableCpuUsage -Value 65
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter "system.webServer/httpCompression/scheme[@name='gzip']" -Name staticCompressionLevel -Value 9
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter "system.webServer/httpCompression/scheme[@name='gzip']" -Name dynamicCompressionLevel -Value 4


# Configuration History:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/configHistory -Name maxHistories -Value 20
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/configHistory -Name period -Value '00:01:00'


# ASP.NET Concurrency:
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT -Filter system.net/connectionManagement -Name . -value @{address='*';maxconnection=5000} -Clr 2.0
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT -Filter system.net/connectionManagement -Name . -value @{address='*';maxconnection=5000} -Clr 4.0
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ASP.NET\2.0.50727.0 -Name MaxConcurrentRequestsPerCPU -Value 5000 -Force | Out-Null

#endregion


#region Configure OS settings


# Enable IIS operational auditing
$log = Get-WinEvent -ListLog Microsoft-IIS-Configuration/Operational
$log.IsEnabled = $true
$log.SaveChanges()


# Correctly disable IPv6:
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters -Name DisabledComponents -Value 0xff -Force | Out-Null


# Processor Scheduling:
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl -Name Win32PrioritySeparation -Value 24 -Force | Out-Null


# Disable SSL2 & SSL3 + Enable TLS 1.1 & TLS 1.2:
$SslRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

New-Item -Path "$SslRegPath\SSL 2.0\Server" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\SSL 2.0\Server" -Name Enabled -Value 0 –PropertyType DWORD | Out-Null

New-Item -Path "$SslRegPath\SSL 3.0\Server" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\SSL 3.0\Server" -Name Enabled -Value 0 –PropertyType DWORD | Out-Null

New-Item -Path "$SslRegPath\TLS 1.1\Server" -Force | Out-Null
New-Item -Path "$SslRegPath\TLS 1.1\Client" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Server" -Name Enabled -Value '0xffffffff' –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Server" -Name DisabledByDefault -Value 0 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Client" -Name Enabled -Value 1 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Client" -Name DisabledByDefault -Value 0 –PropertyType DWORD | Out-Null

New-Item -Path "$SslRegPath\TLS 1.2\Server" -Force | Out-Null
New-Item -Path "$SslRegPath\TLS 1.2\Client" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Server" -Name Enabled -Value '0xffffffff' -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Server" -Name DisabledByDefault -Value 0 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Client" -Name Enabled -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Client" -Name DisabledByDefault -Value 0 -PropertyType DWORD -Force | Out-Null


#endregion

#region Basic Harden IIS

$PSPath = "MACHINE/WEBROOT"

# Debug

     Set-WebConfigurationProperty -pspath $PSPath -filter "system.web/compilation" -name "debug" -value "false"
     Set-WebConfigurationProperty -filter "system.web/compilation" -name "debug" -value "false"

# pages viewStateEncryptionMode

     Set-WebConfigurationProperty -pspath $PSPath -filter "system.web/pages" -name "viewStateEncryptionMode" -value "Always"
     Set-WebConfigurationProperty -filter "system.web/pages" -name "viewStateEncryptionMode" -value "Always"

# httpCookies httpOnlyCookies

     Set-WebConfigurationProperty -pspath $PSPath -filter "system.web/httpCookies" -name "httpOnlyCookies" -value "True"
     Set-WebConfigurationProperty -filter "system.web/httpCookies" -name "httpOnlyCookies" -value "True"

# httpCookies requireSSL

     Set-WebConfigurationProperty -pspath $PSPath -filter "system.web/httpCookies" -name "requireSSL" -value "True"
     Set-WebConfigurationProperty -filter "system.web/httpCookies" -name "requireSSL" -value "True"

# httpRuntime enableHeaderChecking

     Set-WebConfigurationProperty -pspath $PSPath -filter "system.web/httpRuntime" -name "enableHeaderChecking" -value "True"
     Set-WebConfigurationProperty -filter "system.web/httpRuntime" -name "enableHeaderChecking" -value "True"

#httpRuntime enableVersionHeader

     Set-WebConfigurationProperty -pspath $PSPath  -filter "system.web/httpRuntime" -name "enableVersionHeader" -value "True"
     Set-WebConfigurationProperty -filter "system.web/httpRuntime" -name "enableVersionHeader" -value "True"


# customHeaders

     # AddcustomHeaders X-Content-Type-Options
     Add-WebConfigurationProperty -pspath $PSPath  -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='X-Content-Type-Options';value='nosniff'} -Force
     # Add customHeaders X-XSS-Protection
     Add-WebConfigurationProperty -pspath $PSPath  -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='X-XSS-Protection';value='1; mode=block'} -Force
     # Add customHeaders X-Frame-Options
     Add-WebConfigurationProperty -pspath $PSPath  -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='X-Frame-Options';value='SAMEORIGIN'} -Force
     # Remove customHeaders X-Powered-By
     Remove-WebConfigurationProperty  -pspath $PSPath  -filter "system.webServer/httpProtocol/customHeaders" -name "." -AtElement @{name='X-Powered-By'}

#endregion
