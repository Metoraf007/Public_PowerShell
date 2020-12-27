# Notes  : Set-WebConfigEcryption
# Date   : 22.12.2020
# Author : Rotem Simhi
# Version: 2.0.0.3

##########################################################################################################
#                                           HOW TO USE                                                   #
#                                                                                                        #
#                                                                                                        #
#   Encrypt appSettings and connectionStrings Sections for all web sites and web applications            #
#   \.Set-WebConfigEcryption.ps1 -Sections @("appSettings", "connectionStrings")                         #
#                                                                                                        #
#   Encrypt appSettings and connectionStrings Sections                                                   #
#   \.Set-WebConfigEcryption.ps1 -Site "test" -Sections @("appSettings", "connectionStrings")            #
#                                                                                                        #
#   Encrypt appSettings Section                                                                          #
#   \.Set-WebConfigEcryption.ps1 -Site "test" -Sections "appSettings"                                    #
#                                                                                                        #
#                                                                                                        #
#   Decrypt appSettings and connectionStrings Sections for all web sites and web applications            #
#   \.Set-WebConfigEcryption.ps1 -Sections @("appSettings", "connectionStrings")                         #
#                                                                                                        #
#   Decrypt appSettings and connectionStrings Sections                                                   #
#   \.Set-WebConfigEcryption.ps1 -Site "test" -Sections @("appSettings", "connectionStrings") -Decrypt   #
#                                                                                                        #
#   Decrypt appSettings Section                                                                          #
#   \.Set-WebConfigEcryption.ps1 -Site "test" -Sections "appSettings" -Decrypt                           #
#                                                                                                        #
##########################################################################################################

# Load params from user
param($Site = "All", $Sections = @("appSettings", "connectionStrings"), [bool]$Decrypt = $false)
Import-Module -name *web*

# Helper Functions
function Get-Runtimeversion{
    param(
        $applicationPoolVersion
    )

    if ($applicationPoolVersion -eq 'v2.0'){
        $Runtime = 'v2.0.50727'
    }elseif ($applicationPoolVersion -eq'v4.0') {
        $Runtime = 'v4.0.30319'
    }else {
        $Runtime = 'Unknown'
    }
    return $Runtime
}
function Get-IISMap {
    $id = 0
    $SiteCollection = @{}
    $WebSites = Get-Website | where-object {$_.bindings.collection.protocol -like "http*"}

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
    if ($Site = "All") {
        
        foreach ($id in $SiteMap.GetEnumerator() ){
            $Name = $id.Value['Name']
            $SiteLocation = $id.Value['Path']
            $applicationPoolName = $id.Value['applicationPoolName']
            $applicationPoolVersion = $id.Value['applicationPoolVersion']
            
            # Select the Runtime version
            $Runtime = Get-Runtimeversion -applicationPoolVersion $applicationPoolVersion
    
            if ($Runtime -eq 'Unknown'){
                Write-Host "Runtime Unknown" -ForegroundColor Red
                $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\'
            }else{
                $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\{0}' -f ($Runtime)
            }
    
            Set-Location $LocationPath
        
            foreach ($Section in $Sections) {
                if ($Decrypt) {
                    Write-Host "Decrypting Site: $Name, with AppPool: $applicationPoolName" -ForegroundColor Green
                   .\aspnet_regiis.exe -pdf $Section $SiteLocation
                }else {
                    Write-Host "Encrypting Site: $Name, with AppPool: $applicationPoolName" -ForegroundColor Green
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
                
                # Select the Runtime version
                $Runtime = Get-Runtimeversion -applicationPoolVersion $applicationPoolVersion
  
                # Generate the path of the aspnet_regiis according to the Runtime version
                if ($Runtime -eq 'Unknown'){
                    Write-Host "Runtime Unknown" -ForegroundColor Red
                    $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\'
                }else{
                    $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\{0}' -f ($Runtime)
                }
        
                Set-Location $LocationPath
            
                foreach ($Section in $Sections) {
                    if ($Decrypt) {
                        Write-Host "Decrypting Site: $Name, with AppPool: $applicationPoolName" -ForegroundColor Green
                        .\aspnet_regiis.exe -pdf $Section $SiteLocation
                    
                    }else {
                        Write-Host "Encrypting Site: $Name, with AppPool: $applicationPoolName" -ForegroundColor Green
                        .\aspnet_regiis.exe -pef $Section $SiteLocation -prov DataProtectionConfigurationProvider
                    }
                }
            }
        }
    }
}


if ($Decrypt){
    # Decrypt
    Set-Encryption -site $Site -Sections $Sections -Decrypt
}else{
    # Encrypt
    Set-Encryption -site $Site -Sections $Sections 
}



