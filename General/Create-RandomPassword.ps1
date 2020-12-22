function Create-RandomPassword
{
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(20,120)]
        [Int]
        $PasswordLength = 12
    )
    add-type -AssemblyName System.Web
    $Password = [System.Web.Security.Membership]::GeneratePassword($PasswordLength, $PasswordLength / 4)

    #This should never fail, but I'm putting a sanity check here anyways
    if ($Password.Length -ne $PasswordLength)
    {
        throw new Exception("Password returned by GeneratePassword is not the same length as required. Required length: $($PasswordLength). Generated length: $($Password.Length)")
    }

    return $Password
}