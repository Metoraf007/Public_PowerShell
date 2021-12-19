
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

$SiteMap = Get-IISMap

foreach ($id in $SiteMap.GetEnumerator() ){
    $id.Value
}