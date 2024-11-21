Function Check-RunAsAdministrator()
{
  #Get current user context
  $CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  
  #Check user is running the script is member of Administrator Group
  if($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
  {
       Write-host "Script is running with Administrator privileges!"
  }
  else
    {
       #Create a new Elevated process to Start PowerShell
       $ElevatedProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
 
       # Specify the current script path and name as a parameter
       $ElevatedProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"
 
       #Set the Process to elevated
       $ElevatedProcess.Verb = "runas"
 
       #Start the new elevated process
       [System.Diagnostics.Process]::Start($ElevatedProcess)
 
       #Exit from the current, unelevated, process
       Exit
 
    }
}
 
#Check Script is running with Elevated Privileges
Check-RunAsAdministrator


# Processes to kill
#$ProcsToKill = New-Object Collections.Generic.List[String]
$ProcsToKill = @{
    "WinStore.App" = "Microsoft Store"
    "IGCC" = "Intel Graphic Experience"
    "IGCCTray" = "Intel Graphic Experience Tray"
    "igfxCUIService" = "Some Intel Graphics Service"
    "igfxEM" = "Intel Graphics"
    "IntelCpHDCPSvc" = "Intel HD Graphics for Windows"
    "IntelCpHeciSvc" = "IntelCpHeciSvc"
    "WhatsApp" = "WhatsApp"
}
ForEach ($Proc in $ProcsToKill.Keys) {
    $ProcName = $ProcsToKill[$Proc] 
    #Write-Host "Key: $Proc, Value: $($ProcName)"
    if ($Proc -eq $null) {
        continue
    }
    $ProcA = Get-Process -Name $Proc
    if ($ProcA) {
        Write-Host "Stopping process $($ProcName)"
        $ProcA | Stop-Process
        if ($ProcA.started) {
            Write-Host "Stopping process $($ProcName)"
            $ProcA | Stop-Process
        }
    }
}
#Read-Host -Prompt "Press Enter to exit"
#exit


#$ProcsToKill.Add()

# App Names
$appNames = New-Object Collections.Generic.List[String]
$appNames.Add("5319275A.51895FA4EA97F") # WhatsApp Beta
$appNames.Add("Microsoft.NET.Native.Framework.2.2") # Microsoft .Net Native Framework Package 2.2
$appNames.Add("Microsoft.NET.Native.Runtime.2.2") # Microsoft .Net Native Runtime Package 2.2
$appNames.Add("Microsoft.UI.Xaml.2.8") # Microsoft.UI.Xaml.2.8
$appNames.Add("Microsoft.VCLibs.140.00.UWPDesktop") # Microsoft VCLibs 140 00 UWPDesktop
$appNames.Add("Microsoft.VCLibs.140.00") # Microsoft VCLibs 140 00

#Add-AppxPackage -DisableDevelopmentMode -Register
#Get-AppXPackage -AllUsers -Name "5319275A.51895FA4EA97F" | Select-Object Name,Version,Architecture,InstallLocation,Publisher,PublisherId,PackageFamilyName,PackageFullName,IsFramework,PackageUserInformation,IsResourcePackage,IsBundle,IsDevelopmentMode,NonRemovable,Dependencies,IsPartiallyStaged,SignatureKind,Status
$i = 1
ForEach($appName in $appNames) {
    #Get-AppXPackage -AllUsers -Name $appName | Select-Object Name,Version,Architecture,InstallLocation,Publisher,PublisherId,PackageFamilyName,PackageFullName,IsFramework,PackageUserInformation,IsResourcePackage,IsBundle,IsDevelopmentMode,NonRemovable,Dependencies,IsPartiallyStaged,SignatureKind,Status
    $WinApp = Get-AppXPackage -AllUsers -Name $appName | Select-Object Name,Version,Architecture,InstallLocation,Publisher,PackageFamilyName,PackageFullName,PackageUserInformation,IsDevelopmentMode,Status
    $WinAppInstallLoc = $WinApp.InstallLocation

    Write-Host "----------------Started $($i)----------------`n"

    $InstallLocIndex = 1
    ForEach($InstallLoc in $WinAppInstallLoc) {
        Write-Host "$($InstallLocIndex). $InstallLoc"
        Write-Host "Install Location - $($WinAppInstallLoc)`n"
        Write-Host "Executing Command: 'Add-AppxPackage -DisableDevelopmentMode -Register" +  "$($InstallLoc)\AppXManifest.xml'`n" | Out-String

        $exec = Add-AppxPackage -DisableDevelopmentMode -Register "$($InstallLoc)\AppXManifest.xml" | Out-String
        If($?) {
            $success = $true
            #[System.Windows.Forms.MessageBox]::Show('The app $($appName) has been re-registered successfully','App Re-Register Successful')
            Write-Host 'The app $($appName) has been re-registered successfully','App Re-Register Successful'
            Write-Host "Successful"
        } ElseIf($error) {
            $err = $error[0]
            #[System.Windows.Forms.MessageBox]::Show("Failed $($error[0])",'ERROR')
            Write-Host "Failed $($error[0])",'ERROR'
            Write-Host "Error"
        }
        $job = Start-Job { 
            $exec
        }
        Wait-Job $job | Out-Null
        Receive-Job $job
        $InstallLocIndex++
    }
    Write-Host "`n`n`n"


    
    Write-Host "----------------Finished $($i)----------------`n`n`n"
    $i++

    #Write-Host $WinAppInstallLoc
}

Start-Process "C:\Program Files\WindowsApps\Microsoft.WindowsStore_22410.1401.3.0_x64__8wekyb3d8bbwe\WinStore.App.exe"

Read-Host -Prompt "Press Enter to exit"
