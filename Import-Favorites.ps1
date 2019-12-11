function Import-Favorites {
<#
.Synopsis
    Create a .txt containing your favorite URLs and use this function to import them to IE
.DESCRIPTION
   Import URL list from a .txt and creates them in an Internet Explorer favorite folder using COM object
.EXAMPLE
   Import-Favorites -FilePath "C:\users\rotems\Desktop\UrlList.txt" -FavsFolderName 'News WebSites'
.INPUTS
   FilePath = Enter the path to the .txt file as a string
   FavsFolderName = Enter the name of the favorite folder in your IE browser as a string
.NOTES
   The name of the saved link will be the string after the first . in the url: 
   https://www.ynet.co.il -> ynet

#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [String]
        $FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $FavsFolderName
    )
    Begin{
        $IEFav = Join-Path -Path ([Environment]::GetFolderPath('Favorites','None')) -ChildPath $FavsFolderName
        if (-not (Test-Path $IEFav)){
            New-Item -Path $IEFav -ItemType Directory -Force | Out-Null
        }
        $Shell = New-Object -ComObject WScript.Shell
        $Urls = Get-Content -Path $FilePath
    }
    Process{
        foreach ($url in $Urls){
            try{
                $urlName = $url.split(".")[1]
                $FullPath = Join-Path -Path $IEFav -ChildPath "$urlName.url"
                $shortcut = $Shell.CreateShortcut($FullPath)
                $shortcut.TargetPath = $Url
                $shortcut.Save()
            }
            catch [System.Runtime.InteropServices.COMException] {
                Write-Host ("Could not save link: $url") -ForegroundColor red
            }
            catch{
                Write-Host ("What happend??? url was: $url") -ForegroundColor red
            }
        }
    }
    End{
        Write-Host "Done... Your new Favorite urls are in the $FavsFolderName IE Folder"
    }
}
