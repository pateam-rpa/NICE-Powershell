###
# File only tested on 7.2!!!!
###

# Parameters
$InstallerSQLAccount =  "DOMAIN\OLDSQLUSER"
$InstallerVaultAccount =  "DOMAIN\OLDVAULTUSER"
$SQLServiceAccount = 'DOMAIN\NEWSQLUSER'
$VaultServiceAccount = 'DOMAIN\NEWVAULTUSER'
$SQLpassword = "xxxxxx"
$Vaultpassword = "yyyyy"

##List of Services
#get-service | Where-Object {($_.name -like "RT*")}  | select -Property 'Name'
#SQL
$services = @('RTServer Cognos',
'RTServer_ActiveMQ',
'RTSERVER_Subversion',
'RTServerAEService',
'RTServerAMService',
'RTServerApache',
'RTServerCAService',
'RTServerCBService',
'RTServerCCMService',
'RTServerCMService',
'RTServerCMUService',
'RTServerLMService',
'RTServerMHService',
'RTServerRASIService',
'RTServerRTHService',
'RTServerSDSService',
'RTServerSPService',
'RTtomcat')
#Vault
$vaultservices = 'RTServerPasswordStoreService'
#LocalSystem, left as is
#'RTElasticSearch'

## Helperfunctions
function Add-To-Localpolicy {
    param($accountToAdd, $serviceToAdd)

    if( [string]::IsNullOrEmpty($accountToAdd) ) {
	    Write-Host "no account specified"
	    exit
    }


    $sidstr = $null
    try {
	    $ntprincipal = new-object System.Security.Principal.NTAccount "$accountToAdd"
	    $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	    $sidstr = $sid.Value.ToString()
    } catch {
	    $sidstr = $null
    }

    Write-Host "Account: $($accountToAdd)" -ForegroundColor DarkCyan

    if( [string]::IsNullOrEmpty($sidstr) ) {
	    Write-Host "Account not found!" -ForegroundColor Red
	    exit -1
    }

    Write-Host "Account SID: $($sidstr)" -ForegroundColor DarkCyan

    $tmp = [System.IO.Path]::GetTempFileName()

    Write-Host "Export current Policy" -ForegroundColor DarkCyan
    secedit.exe /export /cfg "$($tmp)" 

    $c = Get-Content -Path $tmp 

    $currentSetting = ""

    foreach($s in $c) {
	    if( $s -like "$serviceToAdd*") {
		    $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $currentSetting = $x[1].Trim()
	    }
    }

    if( $currentSetting -notlike "*$($sidstr)*" ) {
	    Write-Host "Modify Setting ""$serviceToAdd""" -ForegroundColor DarkCyan
	
	    if( [string]::IsNullOrEmpty($currentSetting) ) {
		    $currentSetting = "*$($sidstr)"
	    } else {
		    $currentSetting = "*$($sidstr),$($currentSetting)"
	    }
	
	    Write-Host "$currentSetting"
	
	    $outfile = @"
    [Unicode]
    Unicode=yes
    [Version]
    signature="`$CHICAGO`$"
    Revision=1
    [Privilege Rights]
    $serviceToAdd = $($currentSetting)
"@

	    $tmp2 = [System.IO.Path]::GetTempFileName()
	
	
	    Write-Host "Import new settings to Local Security Policy" -ForegroundColor DarkCyan
	    $outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

	    #notepad.exe $tmp2
	    Push-Location (Split-Path $tmp2)
	
	    try {
		    secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
		    #write-host "secedit.exe /configure /db ""secedit.sdb"" /cfg ""$($tmp2)"" /areas USER_RIGHTS "
	    } finally {	
		    Pop-Location
	    }
    } else {
	    Write-Host "NO ACTIONS REQUIRED! Account already in ""$serviceToAdd""" -ForegroundColor DarkCyan
    }

    Write-Host "Done." -ForegroundColor DarkCyan
} 

function Set-ServiceLogon {
    param($Name, $username, $password)
        
    $secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force 
    $creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureStringPwd

    $svcD=gwmi win32_service -computername localhost -filter "name='$Name'" -Credential $Credential 
    $StopStatus = $svcD.StopService() 
    If ($StopStatus.ReturnValue -eq "0")
        {write-host "$Name -> Service Stopped Successfully"} 
    $ChangeStatus = $svcD.change($null,$null,$null,$null,$null,$null,$username,$Password,$null,$null,$null) 
    If ($ChangeStatus.ReturnValue -eq "0")  
        {write-host "$Name -> Successfully Changed User Name"} 
}

function Add-ACL {
    param($foldertostartsearch, $usernametosearch, $usernametoset, $usernametoset2)

	$Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $usernametoset;

	$path = Get-ChildItem $foldertostartsearch -Recurse
	Foreach( $file in $path ) {
		$f = Get-Acl $file.FullName
		if( $f.Owner -eq $usernametosearch ) {
		write-host $file.FullName
			$Acl = $null; # Reset the $Acl variable to $null
			$Acl = Get-Acl -Path $file.FullName; # Get the ACL from the item
			$Ar1 = New-Object System.Security.AccessControl.FileSystemAccessRule($usernametoset, "FullControl", "Allow")
			$Acl.SetAccessRule($Ar1)
			if ($usernametoset2) {
			#no second username to set 
			}
			else { 
				$Ar2 = New-Object System.Security.AccessControl.FileSystemAccessRule($usernametoset2, "FullControl", "Allow")
				$Acl.SetAccessRule($Ar2)
			} 
			$Acl.SetOwner($Account); # Update the in-memory ACL
			Set-Acl -Path $file.FullName -AclObject $Acl;  # Set the updated ACL on the target item
			Write-Host 'ACL Set on file: $file.FullName' -ForegroundColor DarkCyan
		}
	}
}


## Check and disable watchdog if needed
$task = Get-ScheduledTask -TaskName 'RTServer Watchdog'
If ($task.State -eq 'Disabled')  {
	$previousstate = 'Disabled' 
}
else
{
	$previousstate = 'Enabled' 
	Stop-ScheduledTask -TaskName 'RTServer Watchdog'
	Disable-ScheduledTask -TaskName 'RTServer Watchdog'
} 

## Add users to local policies
Add-To-Localpolicy -accountToAdd $SQLServiceAccount -serviceToAdd 'SeServiceLogonRight'
Add-To-Localpolicy -accountToAdd $SQLServiceAccount -serviceToAdd 'SeTcbPrivilege'
Add-To-Localpolicy -accountToAdd $VaultServiceAccount -serviceToAdd 'SeServiceLogonRight'
Add-To-Localpolicy -accountToAdd $VaultServiceAccount -serviceToAdd 'SeTcbPrivilege'
Add-To-Localpolicy -accountToAdd $VaultServiceAccount -serviceToAdd 'SeBatchLogonRight'

## Switch Services users
Set-ServiceLogon -Name $vaultservices -username $VaultServiceAccount -password $Vaultpassword
foreach ($service in $services) {
    Set-ServiceLogon -Name $service -username $SQLServiceAccount -password $SQLpassword
}

## Add ACL permissions for Vault users 
# Searches for all files in keymanagement folder and adds vault user, leaves the old user as well
Add-ACL -foldertostartsearch $env:RTS_HOME'\KeyManagement\' -usernametosearch $InstallerVaultAccount -usernametoset $VaultServiceAccount -$usernametoset2 $InstallerSQLAccount 

## Add ACL permissions for SQL users 
# Searches for all files in install folder and adds SQL user, leaves the old user as well
Add-ACL -foldertostartsearch $env:RTS_HOME -usernametosearch $InstallerSQLAccount -usernametoset $SQLServiceAccount

## Update Scheduled task user
Set-ScheduledTask -TaskName 'RTServer Vault' -User $VaultServiceAccount -Password $Vaultpassword

## Run watchdog to restart services
Start-ScheduledTask -TaskName 'RTServer Startup' 

## Reinstate Watchdog state if needed
If ($previousstate -eq 'Enabled')  {
	Enable-ScheduledTask -TaskName 'RTServer Watchdog'
}

## Not used, for archiving
# list of files owned by vault
@" 
E:\nice_systems\RTServer\KeyManagement\bin\vault_bootstrap.cmd
E:\nice_systems\RTServer\KeyManagement\bin\vault_common_functions.cmd
E:\nice_systems\RTServer\KeyManagement\bin\vault_Global_Params.cmd
E:\nice_systems\RTServer\KeyManagement\bin\vault_init.cmd
E:\nice_systems\RTServer\KeyManagement\bin\vault_run.cmd
E:\nice_systems\RTServer\KeyManagement\bin\vault_unseal.cmd
E:\nice_systems\RTServer\KeyManagement\config\config.json
"@
# list of files owned by sql
@" 
E:\nice_systems\RTServer\ActiveMQ\conf\jmx.password
E:\nice_systems\RTServer\Apache\conf\extra\svn.rts.ldap.pass
E:\nice_systems\RTServer\Apache\conf\extra\svn.rts.sds.pass
E:\nice_systems\RTServer\config\properties\jmx.password
E:\nice_systems\RTServer\Subversion\repos\conf\passwd
E:\nice_systems\RTServer\Subversion\repos\conf\svn_passwd
"@