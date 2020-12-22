[String]$dbname = "TEST_DB";
[String]$UserName = "ROTEMTEST";
[String]$Password = 'PASSPASSPASS';

# Open ADO.NET Connection with Windows authentification to local SQLSERVER.
$con = New-Object Data.SqlClient.SqlConnection;
$con.ConnectionString = "Data Source=192.168.161.36;Initial Catalog=master;Integrated Security=True;";
$con.Open();
 
 function Test-DB ($dbname){
# Select-Statement for AD group logins
    $sql = "SELECT name
            FROM sys.databases
            WHERE name = '$dbname';";
     
    # New command and reader.
    $cmd = New-Object Data.SqlClient.SqlCommand $sql, $con;
    $rd = $cmd.ExecuteReader();
    if ($rd.Read())
    {   
        Return $true  
    }else {
        return $false
    }
    
    $rd.Dispose()
}

if ((Test-DB -dbname $dbname) -eq $false){

    # Create the DB  
    $sql = "CREATE DATABASE [$dbname];"
    $cmd = New-Object Data.SqlClient.SqlCommand $sql, $con
    $Respose = $cmd.ExecuteNonQuery() 
    Write-Host "Database $dbname is created!" -ForegroundColor Green
}else {
     Write-Host "Database $dbname already exists" -ForegroundColor Red
}
# Creates the login AbolrousHazem with password '340$Uuxwp7Mcxo7Khy'. 
 
$sql = "CREATE LOGIN [$UserName]
	WITH PASSWORD = N'$Password', DEFAULT_DATABASE=[$dbname], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;"
$cmd = New-Object Data.SqlClient.SqlCommand $sql, $con;
$Respose = $cmd.ExecuteNonQuery();     
Write-Host "User Created: $UserName" -ForegroundColor Green

# Creates a database user for the login created above.  

$sql = "USE [$dbname]
        CREATE USER [$UserName] FOR LOGIN [$UserName];
        ALTER USER [$UserName] WITH DEFAULT_SCHEMA=[$UserName];"
$cmd = New-Object Data.SqlClient.SqlCommand $sql, $con;
$Respose =  $cmd.ExecuteNonQuery();

$sql = "CREATE SCHEMA [$UserName] AUTHORIZATION [$UserName];"
$cmd = New-Object Data.SqlClient.SqlCommand $sql, $con;
$Respose =  $cmd.ExecuteNonQuery(); 


$sql = "USE [$dbname]
        ALTER ROLE [db_owner] ADD MEMBER [$UserName];"
$cmd = New-Object Data.SqlClient.SqlCommand $sql, $con;
$Respose =  $cmd.ExecuteNonQuery(); 
   
Write-Host "Enabled Login for: $UserName for DB: $dbname";


# Close & Clear all objects.
$cmd.Dispose();
$con.Close();
$con.Dispose();