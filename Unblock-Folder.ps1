Clear-Host
Write-Host "================ This will unblock all files in a folder ================"


$foldername = New-Object windows.forms.FolderBrowserDialog   
$foldername.Description = "Select Folder to unblock, make sure to select the root of your unzipped installation files"
$foldername.rootfolder = "MyComputer"
 
Write-Host "Select Downloaded Settings File... (see FileOpen Dialog)" -ForegroundColor Green  
#$result = $openFileDialog.ShowDialog()   # Display the Dialog / Wait for user response 
# in ISE you may have to alt-tab or minimize ISE to see dialog box 
#$result 

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder = $foldername.SelectedPath
        Get-Childitem -recurse $folder | Unblock-File
        Write-Host "Completed unblocking files in: " $folder -ForegroundColor Green  
    }

