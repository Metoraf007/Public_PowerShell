# Notes  : Encrypt-WebConfig
# Date   : 22.12.2020
# Author : Rotem Simhi
# Version: 2.0.0.1

# Load params from user
param($Site = "All", $Sections = @("appSettings", "connectionStrings"))
Import-Module -name *web*

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
    $WebSites = Get-Website

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
            #$Name = $id.Value['Name']
            $Path = $id.Value['Path']
            #$applicationPoolName = $id.Value['applicationPoolName']
            $applicationPoolVersion = $id.Value['applicationPoolVersion']
            
            # Select the runtime version
            $Runtime =Get-Runtimeversion -applicationPoolVersion $applicationPoolVersion
    
            if ($runtime -eq 'Unknown'){
                break
            }else{
                $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\{0}' -f ($AppPoolVersion.runtime)
            }
    
            Set-Location $LocationPath
        
            foreach ($Section in $Sections) {
                if ($Decrypt) {
                   .\aspnet_regiis.exe -pdf $Section $SiteLocation
                }else {
                   .\aspnet_regiis.exe -pef $Section $SiteLocation -prov DataProtectionConfigurationProvider
                }
            }
        }
    }else{
        foreach ($id in $SiteMap.GetEnumerator() ){
            $Sites = $id.value | Where-Object name -eq $Site
            foreach ($site in $sites){

                #$Name = $site.Name
                $Path = $site.Path
                #$applicationPoolName = $id.applicationPoolName
                $applicationPoolVersion = $id.applicationPoolVersion
                
                # Select the runtime version
                $Runtime =Get-Runtimeversion -applicationPoolVersion $applicationPoolVersion
  
                # Generate the path of the aspnet_regiis according to the runtime version
                if ($runtime -eq 'Unknown'){
                    break
                }else{
                    $LocationPath = 'C:\Windows\Microsoft.NET\Framework64\{0}' -f ($runtime)
                }
        
                Set-Location $LocationPath
            
                foreach ($Section in $Sections) {
                    if ($Decrypt) {
                    .\aspnet_regiis.exe -pdf $Section $Path
                    
                    }else {
                    .\aspnet_regiis.exe -pef $Section $Path -prov DataProtectionConfigurationProvider
                    }
                }
            }
        }
    }
}



# Decrypt config sections
#$Sections = "appSettings", "connectionStrings"

# Encrypt
Set-Encryption -site $Site -Sections $Sections 

# Decrypt
Set-Encryption -site $Site -Sections $Sections -Decrypt

