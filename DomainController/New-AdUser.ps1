Import-Module -Name "ActiveDirectory"
$Csv = Import-Csv -Path "E:\Temp\rotems2.csv"
ForEach($User in $Csv) {

    $NewUser = @{
    GivenName            = $User.GivenName
    Surname              = $User.Surname
    Name                 = $User.GivenName + " " +  $User.Surname
    DisplayName          = $User.GivenName + " " +  $User.Surname
    EmailAddress         = $User.EmailAddress
    SamAccountName       = $User.SamAccountName 
    UserPrincipalName    = $User.SamAccountName+'@'+(gwmi win32_NTDomain).DnsForestName
    OfficePhone          = $User.OfficePhone
    Office               = $User.Office 
    AccountPassword      = (ConvertTo-SecureString (Get-Content E:\Temp\pass.txt) -AsPlainText -force)
    Enabled              = $True
    PasswordNeverExpires = $True
    CannotChangePassword = $True
    }

    New-ADUser @NewUser
    }