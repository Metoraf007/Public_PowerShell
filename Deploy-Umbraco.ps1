[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$Package,

    [Parameter(Mandatory = $true)]
    [string]$Hostname,

    [int]$Port = 80,

    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [string]$Email,
	#Minimun 10 chars
    [Parameter(Mandatory = $true)]
    [string]$Password,

    [Parameter(Mandatory = $true)]
    [ValidateSet("SqlCe", "SqlServer", "MySql", "SqlAzure")]
    [string]$DatabaseType = "SqlServer",

    [string]$SqlServer,
    [string]$DatabaseName = "umbraco-cms",
    [bool]$SqlUseIntegratedAuthentication = $false,
    [string]$SqlUsername,
    [string]$SqlPassword
)

Import-Module WebAdministration

Enum DatabaseType {
    SqlCe
    SqlServer
    MySql
    SqlAzure
}

Enum ResultType {
    Success
    Error
    Warning
}

Function ConfigureUmbraco {
    Param([string]$url, [string]$username, [string]$email, [string]$password, [string]$databaseType, [string]$sqlServer, [string]$databaseName, [bool]$sqlUseIntegratedAuthentication, [string]$sqlUsername, [string]$sqlPassword)

    try { $response = Invoke-WebRequest $("{0}/install/api/GetSetup" -f $url) -SessionVariable 'session' -Method GET }
    catch { $response = $null }

    if ($null -ne $response) {
        $responseData = ParseResponse($response);

        $installId = $responseData.installId;
        $isUpgrade = $responseData.steps[0].name -eq "Upgrade";

        if ($isUpgrade -eq $false) {
            $data = @{
                installId    = $installId
                instructions = @{
                    User                = @{
                        name                  = $username
                        email                 = $email
                        password              = $password
                        subscribeToNewsLetter = $false
                    }
                    DatabaseConfigure   = @{
                        dbType = [DatabaseType]::$databaseType
                    }
                    ConfigureMachineKey = $true
                    StarterKitDownload  = "00000000-0000-0000-0000-000000000000"
                }
            }

            if ([DatabaseType]::$databaseType -ne [DatabaseType]::SqlCe) {
                $data.instructions.DatabaseConfigure.server = $sqlServer;
                $data.instructions.DatabaseConfigure.databaseName = $databaseName;

                if ($sqlUseIntegratedAuthentication) {
                    $data.instructions.DatabaseConfigure.integratedAuth = $true;
                }
                else {
                    $data.instructions.DatabaseConfigure.login = $sqlUsername;
                    $data.instructions.DatabaseConfigure.password = $sqlPassword;
                }
            }

            if ((StartUmbracoProcess $("{0}/install/api/PostPerformInstall" -f $url) $data $session) -eq $false) {
                Error "An error occured during Umbraco configuration"
            }
        }
        else {
            $model = ParseResponse($response).steps[0].model;
    
            $data = @{
                username = $email
                password = $password
            };
    
            try { $response = Invoke-WebRequest $("{0}/umbraco/backoffice/UmbracoApi/Authentication/PostLogin" -f $url) -WebSession $session -Method POST -Body ($data | ConvertTo-Json -Depth 5) -ContentType "application/json" }
            catch { $response = $null}
        
            if ($null -ne $response) {
                $data = @{
                    installId    = $installId
                    instructions = @{
                        Upgrade = $model
                    }
                }
    
                if ((StartUmbracoProcess $("{0}/install/api/PostPerformInstall" -f $url) $data $session) -eq $false) {
                    Error "An error occured during Umbraco configuration"
                }
            }
            else {
                Error "The authentication to Umbraco back office failed";
            }
        }

        Success
    }
    else {
        Warning "No configuration needed"
    }
}

Function CreateWebApplicationPool {
    Param([string]$name)

    Begin {
        Push-Location
    }

    Process {
        Set-Location "IIS:\AppPools\"
    
        if ((Test-Path $name -PathType container) -eq $false) {
            New-Item $name | Out-Null
    
            Success
        }
        else {
            Warning "The application pool already exists."
        }
    }

    End {
        Pop-Location
    }
}

Function CreateWebSite {
    Param([string]$hostname, [string]$port, [string]$destination)

    Begin {
        Push-Location
    }

    Process {
        $name = GetSiteName $hostname $port
    
        Set-Location "IIS:\Sites\"
    
        if ((Test-Path $name -PathType container) -eq $true) {
            Warning "The IIS site already exists."
        }
        else {
            $site = New-Item $name -bindings @{protocol = "http"; bindingInformation = $(":{0}:" -f $port) + $hostname} -PhysicalPath $destination
            $site | Set-ItemProperty -Name "applicationPool" -Value $hostname
    
            Success
        }
    }
    End {
        Pop-Location
    }
}

Function EnsureHostEntry {
    Param([string]$ip, [string]$hostName)

    $hostFilename = "C:\Windows\System32\drivers\etc\hosts"

    [array]$content = [System.IO.File]::ReadAllLines($hostFilename, [System.Text.Encoding]::ASCII) | Select-String $hostName -NotMatch

    $content += $("{0}`t`t{1}" -f $ip, $hostName);

    [System.IO.File]::WriteAllLines($hostFilename, $content, [System.Text.Encoding]::ASCII)

    Success
}

Function Error {
    Param([string]$message)

    return @{
        Type = [ResultType]::Error
        Message = $message
    }
}

Function ExtractSite {
    Param([string]$source, [string]$destination)

    $webConfigPath = Join-Path -Path $destination -ChildPath "Web.config"
    $isUpgrade = Test-Path $destination;

    if ($isUpgrade) {
        $webConfigBackupPath = Join-Path -Path $destination -ChildPath ("Web.config.{0}.bak" -f (Get-Date).Ticks)

        $webConfig = [xml](Get-Content ($webConfigPath) -Encoding UTF8)

        $previousVersion = ($webConfig.configuration.appSettings.add | Where-Object { $_.key -eq "umbracoConfigurationStatus" }).value
        $previousConnectionString = ($webConfig.configuration.connectionStrings.add | Where-Object { $_.name -eq "umbracoDbDSN" }).connectionString
        $previousSqlProvider = ($webConfig.configuration.connectionStrings.add | Where-Object { $_.name -eq "umbracoDbDSN" }).providerName
        $machineKey = $webConfig.configuration["system.web"].machineKey

        Copy-Item $webConfigPath -Destination $webConfigBackupPath

        #Waiting for locks to be released
        Start-Sleep -Seconds 60
    }

    Expand-Archive -LiteralPath (Get-Item $source).FullName -DestinationPath $destination -Force

    if ($isUpgrade) {
        $webConfig = [xml](Get-Content ($webConfigPath) -Encoding UTF8)

        ($webConfig.configuration.appSettings.add | Where-Object { $_.key -eq "umbracoConfigurationStatus" }).value = $previousVersion;
        ($webConfig.configuration.connectionStrings.add | Where-Object { $_.name -eq "umbracoDbDSN" }).connectionString = $previousConnectionString;
        ($webConfig.configuration.connectionStrings.add | Where-Object { $_.name -eq "umbracoDbDSN" }).providerName = $previousSqlProvider;

        if ($null -ne $machineKey) {
            $node = $webConfig.ImportNode($machineKey, $true);
            $webConfig.configuration["system.web"].AppendChild($node) | Out-Null;
        }

        $webConfig.Save($webConfigPath)
    }

    Success
}

Function GetSiteName {
    Param([string]$hostname, [string]$port)

    return $("{0}{1}" -f $hostname, $port);
}

Function GetSiteUrl {
    Param([string]$hostname, [string]$port)

    return ("http://{0}:{1}" -f $hostname, $port);
}

Function HandleResult {
    Param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Hashtable]$result
    )

    Process {
        if ($result.Type -eq [ResultType]::Success) {
            Write-Host "Done!" -ForegroundColor Cyan
        }

        if ($result.Type -eq [ResultType]::Warning) {
            Write-Host $result.Message -ForegroundColor Yellow
        }

        if ($result.Type -eq [ResultType]::Error) {
            Write-Host $result.Message -ForegroundColor Red

            throw "Deployment can't continue..."
        }
    }
}

Function ParseResponse {
    Param([object]$response)

    return ($response.Content.Substring($response.Content.IndexOf("{")) | ConvertFrom-Json)
}

Function SetPermissions {
    Param([string]$directory, [string]$appPoolName)

    $acl = Get-Acl $destination

    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($("IIS APPPOOL\{0}" -f $appPoolName), "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)

    Set-Acl $destination $acl

    $acl = Get-Acl $destination

    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IUSR", "Read", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)

    Set-Acl $destination $acl

    $acl = Get-Acl $destination

    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "Read", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)

    Set-Acl $destination $acl

    Success
}

Function StartSite {
    Param($name)

    Get-Website $name | Start-WebSite

    Success
}

Function StartUmbracoProcess {
    Param([string]$url, [Hashtable]$data, [Microsoft.PowerShell.Commands.WebRequestSession]$session)

    $continue = $true;

    do {
        try {
            $response = Invoke-WebRequest $url -WebSession $session -Method POST -Body ($data | ConvertTo-Json -Depth 5) -ContentType "application/json; charset=utf-8" 
            $continue = !($response.Content.SubString(5) | Convertto-Json).complete
		# $continue = !(ParseResponse($response)).complete;
        }
        catch {
            return $false
        }
    } while ($continue -eq $true);

    return $true
}

Function StartWebApplicationPool {
    Param([string]$name)

    $appPool = Get-Item $("IIS:\AppPools\{0}" -f $name)

    if ($appPool.State -eq "Stopped") {
        $appPool.Start()
    }

    Success
}

Function StopSite {
    Param($name)

    Get-Website $name | Stop-WebSite

    Success
}

Function StopWebApplicationPool {
    Param([string]$name)

    $appPool = Get-Item $("IIS:\AppPools\{0}" -f $name)

    if ($appPool.State -eq "Started") {
        $appPool.Stop()
    }

    Success
}

Function Success {
    return @{
        Type = [ResultType]::Success
    }
}

Function Warning {
    Param([string]$message)

    return @{
        Type = [ResultType]::Warning
        Message = $message
    }
}

Clear-Host

$destination = $("C:\inetpub\wwwroot\{0}{1}" -f $hostname, $port)

Write-Host "IIS configuration"
Write-Host -NoNewline "`tCreating the web application pool... " -ForegroundColor Green

CreateWebApplicationPool $hostname | HandleResult

Write-Host -NoNewline "`tCreating the IIS Site... " -ForegroundColor Green

CreateWebSite $hostname $port $destination | HandleResult

Write-Host -NoNewline "`tStopping the site... " -ForegroundColor Green

StopSite (GetSiteName $hostname $port) | HandleResult

Write-Host -NoNewline "`tStopping the application pool... " -ForegroundColor Green

StopWebApplicationPool $hostname | HandleResult

Write-Host "`nDestination folder"

Write-Host -NoNewline "`tExtracting files... " -ForegroundColor Green

ExtractSite $package $destination | HandleResult

Write-Host -NoNewline "`tSetting the permission... " -ForegroundColor Green

SetPermissions $destination $hostname | HandleResult

Write-Host -NoNewline "`tUpdating host file... " -ForegroundColor Green

EnsureHostEntry "127.0.0.1" $hostname | HandleResult

Write-Host -NoNewline "`tSarting the application pool... " -ForegroundColor Green

StartWebApplicationPool $hostname | HandleResult

Write-Host -NoNewline "`tStarting the site... " -ForegroundColor Green

StartSite (GetSiteName $hostname $port) | HandleResult

Write-Host "`nUmbraco"

Write-Host -NoNewline "`tConfiguring... " -ForegroundColor Green

ConfigureUmbraco (GetSiteUrl $hostname $port) $username $email $password $databaseType $sqlServer $databaseName $sqlUseIntegratedAuthentication $sqlUsername $sqlPassword | HandleResult
