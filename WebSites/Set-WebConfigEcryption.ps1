# Notes  : Set-WebConfigEcryption
# Date   : 28.01.2021
# Author : Rotem Simhi
# Version: 2.0.0.5

#############################################################################################################
#                                           HOW TO USE                                                      #
#                                                                                                           #
#                                                                                                           #
#   Encrypt appSettings and connectionStrings Sections for all web sites and web applications               #
#   \.Set-WebConfigEcryption -Sections @("appSettings", "connectionStrings")                                #
#                                                                                                           #
#   Encrypt appSettings and connectionStrings Sections                                                      #
#   \.Set-WebConfigEcryption -Site "test" -Sections @("appSettings", "connectionStrings")                   #
#                                                                                                           #
#   Encrypt appSettings Section                                                                             #
#   \.Set-WebConfigEcryption -Site "test" -Sections "appSettings"                                           #
#                                                                                                           #
#                                                                                                           #
#   Decrypt appSettings and connectionStrings Sections for all web sites and web applications               #
#   \.Set-WebConfigEcryption -Sections @("appSettings", "connectionStrings") -Decrypt $Dycrypt              #
#                                                                                                           #
#   Decrypt appSettings and connectionStrings Sections                                                      #
#   \.Set-WebConfigEcryption -Site "test" -Sections @("appSettings", "connectionStrings") -Decrypt $Dycrypt #
#                                                                                                           #
#   Decrypt appSettings Section                                                                             #
#   \.Set-WebConfigEcryption -Site "test" -Sections "appSettings" -Decrypt $Dycrypt                         #
#                                                                                                           #
#############################################################################################################

# Load params from user
param($Site = "All", $Sections = @("appSettings", "connectionStrings"), [bool]$Decrypt = $true)
Import-Module -name *web*

# Helper Functions
function Get-Runtimeversion{
    param(
        $applicationPoolVersion
    )

    if ($applicationPoolVersion -eq 'v2.0'){
        $runtime = 'v2.0.50727'
    }elseif ($applicationPoolVersion -eq'v4.0') {
        $runtime = 'v4.0.30319'
    }else {
        $runtime = 'Unknown'
    }
    return $runtime
}
function Get-IISMap {
    $id = 0
    $SiteCollection = @{}
    $WebSites = Get-Website | where {$_.bindings.collection.protocol -like "http*"}

    # Map each of the websites
    foreach ($webSite in $WebSites){
        $WebSiteName = $website.name
        $WebSitePath = $WebSite.physicalPath
        $applicationPoolName = $WebSite.applicationPool
        $applicationPoolVersion = Get-IISAppPool -Name $applicationPoolName | Select-Object -ExpandProperty ManagedRuntimeVersion
        
        $SiteCollection += @{
            $id = @{
                Name                   = $WebSiteName
                Path                   = $WebSitePath
                applicationPoolName    = $applicationPoolName
                applicationPoolVersion = $applicationPoolVersion
            }
        }
        $id++

        $WebApplications = Get-WebApplication -Site $WebSiteName

        # Map each of the applications in the web site
        foreach ($WebApplication in $WebApplications){
            
            $WebApplicationName = $WebApplication.path -replace "/"
            $WebApplicationPath = $WebApplication.PhysicalPath
            $applicationPoolName = $WebApplication.applicationPool
            $applicationPoolVersion = Get-IISAppPool -Name $applicationPoolName | Select-Object -ExpandProperty ManagedRuntimeVersion

            $SiteCollection += @{
                $id        = @{
                    Name                   = $WebApplicationName
                    Path                   = $WebApplicationPath
                    applicationPoolName    = $applicationPoolName
                    applicationPoolVersion = $applicationPoolVersion
                }
            }
            $id++
        }
    }

    return $SiteCollection
}

function Backup-Config {
    param(
        $SitePath
    )

    $ConfigPath = '{0}\web.config' -f $SitePath
    $BackupFolder = 'D:\Backup\{0:yyyy}\{1}' -f (Get-Date), (Split-Path -Leaf $SiteLocation)

    if (-not (Test-Path $BackupFolder)){
        New-Item $BackupFolder -Force | Out-Null
    }
    Copy-Item -Path $ConfigPath -Destination $BackupFolder -Force
}

# Encrypt/Decrypt configuration files
function Set-Encryption  {
    param (
        [string]
        $Site,
        [array]
        $Sections,
        [bool]
        $Decrypt
    )

    $SiteMap = Get-IISMap
    $SiteMap.values

    if ($Site = "All") {
        
        foreach ($id in $SiteMap.GetEnumerator() ){
            $Name = $id.Value['Name']
            $SiteLocation = $id.Value['Path']
            $applicationPoolName = $id.Value['applicationPoolName']
            $applicationPoolVersion = $id.Value['applicationPoolVersion']
            
            

            Write-Host "Working on Site: $Name, AppPool: $applicationPoolName" -ForegroundColor Green

            #Backup Web.Config
            Write-Host "Backing up web.config from $name"
            Backup-Config $SiteLocation

            # Select the runtime version
            $Runtime = Get-Runtimeversion -applicationPoolVersion $applicationPoolVersion
    
            if ($runtime -eq 'Unknown'){
                Write-Host "Unknown runtime in $Name"
                $LocationPath = 'C:\Windows\Microsoft.NET\Framework64'
            }else{
                $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\{0}' -f ($runtime)
            }
    
            Set-Location $LocationPath
        
            foreach ($Section in $Sections) {
                if ($Decrypt) {
                    Write-Host "Decrypting $Section in Site: $Name, AppPool: $applicationPoolName" -ForegroundColor Green
                   .\aspnet_regiis.exe -pdf $Section $SiteLocation
                }else {
                    Write-Host "Encrypting $Section in Site: $Name, AppPool: $applicationPoolName" -ForegroundColor Green
                   .\aspnet_regiis.exe -pef $Section $SiteLocation -prov DataProtectionConfigurationProvider
                }
            }
        }
    }else{
        foreach ($id in $SiteMap.GetEnumerator() ){
            $Sites = $id.value | Where-Object name -eq $Site
            foreach ($site in $sites){

                $Name = $site.Name
                $SiteLocation = $site.Path
                $applicationPoolName = $id.applicationPoolName
                $applicationPoolVersion = $id.applicationPoolVersion
                
                
                #Backup Web.Config
                Write-Host "Backing up web.config from $name"
                Backup-Config $SiteLocation

                # Select the runtime version
                $Runtime = Get-Runtimeversion -applicationPoolVersion $applicationPoolVersion
  
                # Generate the path of the aspnet_regiis according to the runtime version
                if ($runtime -eq 'Unknown'){
                    Write-Host "Unknown runtime in $Name"
                    $LocationPath = 'C:\Windows\Microsoft.NET\Framework64'
                }else{
                    $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\{0}' -f ($runtime)
                }
        
                Set-Location $LocationPath
            
                foreach ($Section in $Sections) {
                    if ($Decrypt) {
                    Write-Host "Decrypting $Section in Application: $Name, AppPool: $applicationPoolName" -ForegroundColor Green
                    .\aspnet_regiis.exe -pdf $Section $SiteLocation
                    
                    }else {
                    Write-Host "Encrypting $Section in Application: $Name, AppPool: $applicationPoolName" -ForegroundColor Green
                    .\aspnet_regiis.exe -pef $Section $SiteLocation -prov DataProtectionConfigurationProvider
                    }
                }
            }
        }
    }
}

Set-Encryption -site $Site -Sections $Sections -Decrypt $Decrypt
