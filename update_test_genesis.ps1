# Script assumes it is located at C:\genesis_test_update

# Get settings and assign to $h
# To access $h.Get_Item("MySetting1")
Get-Content "C:\genesis_test_update\settings.txt" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }

# Global variables, could most likely be done to avoid needing them.  The 'copy-backup-dmb' function writes to them.
$backup_dmp_path = ''
$backup_dmp_path_bz2 = ''

# Assigning settings to local variables.
$tomcat_service = $h.Get_Item("Tomcat_Service_Name")
$test_conf_location = $h.Get_Item("Tomcat_Test_Location")

$sql_prod_creds = $h.Get_Item("System_Account")
$sql_test_creds = $h.Get_Item("Test_Account")

Function disable-test-instance
{
    #Stop Tomcat
    Stop-Service $tomcat_service
    Start-Sleep -s 30

    #Rename vhost
    Rename-Item $test_conf_location test.xml~

    #Start Tomcat
    Start-Service $tomcat_service
}

Function copy-backup-dmb
{
    $i = 0
    $filefound = $False
    while($filefound -eq $False)
    {
        
        $DateStr = Get-Date
        $DateStr = $DateStr.AddDays($i).ToString("MM-dd-yyyy")
        
        $global:backup_dmp_path = "D:\genesis\tmp\$DateStr.dmp"
        $global:backup_dmp_path_bz2 = "D:\genesis\tmp\$DateStr.dmp.bz2"
        
        Write-Host "Checking for Backup: 'D:\genesis\backups\$DateStr.dmp.bz2'"
        
        # file exists
        If (Test-Path D:\genesis\backups\$DateStr.dmp.bz2){
            # // File exists
            Write-Host "Copying backup file: 'D:\genesis\backups\$DateStr.dmp.bz2' > $backup_dmp_path_bz2"
            Copy-Item D:\genesis\backups\$DateStr.dmp.bz2 $backup_dmp_path_bz2
            
            $filefound = $True
        }
        
        # decrement to go back 1 day and check for backup
        $i--
    }
}

Function decompress-backup
{
    Write-Host "Decompressing Backup: $global:backup_dmp_path"
    & bunzip2 $global:backup_dmp_path_bz2
}

Function clear-test-db
{
    Write-Host "Clearing Test Database"
    & sqlplus $sql_prod_creds "@C:\genesis_test_update\drop_test.sql"
}

Function import-test-db
{
    Write-Host "Importing Production data to Test"
    & imp $sql_test_creds file=$global:backup_dmp_path full=yes 
}

Function disable-scheduler-reports
{
    Write-Host "Clearing Test Database"
    & sqlplus $sql_test_creds "@C:\genesis_test_update\disable_scheduler.sql"
}

Function enable-test-instance
{
    #Stop Tomcat
    Stop-Service $tomcat_service
    Start-Sleep -s 30

    #Rename vhost
    Rename-Item test_conf_location~ test.xml

    
    #Start Tomcat
    Start-Service $tomcat_service
    
}

Function finishing-database-steps
{
    Write-Host "Finishing Modifications to Test Database"
    & sqlplus $sql_test_creds "@C:\genesis_test_update\last_steps.sql"
}

#disable-test-instance
#copy-backup-dmb
#decompress-backup
#clear-test-db
#import-test-db
#disable-scheduler-reports

#enable-test-instance
finishing-database-steps