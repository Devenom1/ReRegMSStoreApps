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


# Load required assemblies
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.Application]::EnableVisualStyles()


## Set up the environment
Add-Type -AssemblyName System.Windows.Forms
$LastColumnClicked = 0 # tracks the last column number that was clicked
$LastColumnAscending = $false # tracks the direction of the last sort of this column

# Start Creating Functions
Function GetApps{

    # Reset the columns and content of listview_Apps before adding data to it.
    $listview_Apps.Items.Clear()
    $listview_Apps.Columns.Clear()
    
    # Get a list and create an array of all running processes
    # $Processes = Get-Process | Select Id,ProcessName,Handles,NPM,PM,WS,VM,CPU,Path

    # Get a list and create an array of all apps on your system
    $WinApps = Get-AppXPackage -AllUsers | Select Name,Version,Architecture,InstallLocation,Publisher,PublisherId,PackageFamilyName,PackageFullName,IsFramework,PackageUserInformation,IsResourcePackage,IsBundle,IsDevelopmentMode,NonRemovable,Dependencies,IsPartiallyStaged,SignatureKind,Status
    
    # Compile a list of the properties stored for the first indexed app "0"
    $WinAppProperties = $WinApps[0].psObject.Properties

    # Create a column in the listView for each property
    $listview_Apps.Columns.Add("Index") | Out-Null
    $WinAppProperties | ForEach-Object {
        $listview_Apps.Columns.Add("$($_.Name)") | Out-Null
    }

    $i = 1
    # Looping through each object in the array, and add a row for each
    ForEach ($WinApp in $WinApps){

        # Create a listViewItem, and assign it it's first value
        $WinAppListViewItem = New-Object System.Windows.Forms.ListViewItem($i)
        $i = $i + 1

        # For each properties, except for 'Id' that we've already used to create the ListViewItem,
        # find the column name, and extract the data for that property on the current object/process 
        #$WinApp.psObject.Properties | Where {$_.Name -ne "RunspaceId"} | ForEach-Object {
        $WinApp.psObject.Properties | ForEach-Object {
            $ColumnName = $_.Name
            Write-Output $ColumnName
            $WinAppListViewItem.SubItems.Add("$($WinApp.$ColumnName)") | Out-Null
        }

        # Add the created listViewItem to the ListView control
        # (not adding 'Out-Null' at the end of the line will result in numbers outputed to the console)
        $listview_Apps.Items.Add($WinAppListViewItem) | Out-Null

    }

    # Resize all columns of the listView to fit their contents
    $listview_Apps.AutoResizeColumns("HeaderSize")

}

## Event handler
function SortListView {
    param([parameter(Position=0)][UInt32]$Column)
 
    $Numeric = $true # determine how to sort
 
    # if the user clicked the same column that was clicked last time, reverse its sort order. otherwise, reset for normal ascending sort
    Write-Host "Last Column Clicked: $($Script:LastColumnClicked)"
    Write-Host "Column: $($Column)"
    Write-Host "Last Column Ascending: $($Script:LastColumnAscending)"
    if($Script:LastColumnClicked -eq $Column) {
        $Script:LastColumnAscending = -not $Script:LastColumnAscending
    } else {
        $Script:LastColumnAscending = $true
    }
    $Script:LastColumnClicked = $Column
    $ListItems = @(@(@())) # three-dimensional array; column 1 indexes the other columns, column 2 is the value to be sorted on, and column 3 is the System.Windows.Forms.ListViewItem object
 
    foreach($ListItem in $listview_Apps.Items) {
        # if all items are numeric, can use a numeric sort
        if($Numeric -ne $false) { # nothing can set this back to true, so don't process unnecessarily
            try {
                $Test = [Double]$ListItem.SubItems[[int]$Column].Text
            } catch {
                $Numeric = $false # a non-numeric item was found, so sort will occur as a string
            }
        }
        $ListItems += ,@($ListItem.SubItems[[int]$Column].Text,$ListItem)
    }
 
    # create the expression that will be evaluated for sorting
    $EvalExpression = {
        if($Numeric) { return [Double]$_[0] }
        else { return [String]$_[0] }
    }
 
    # all information is gathered; perform the sort
    $ListItems = $ListItems | Sort-Object -Property @{Expression=$EvalExpression; Ascending=$Script:LastColumnAscending}
 

    Write-Host "Start Update"
    ## the list is sorted; display it in the listview
    $listview_Apps.BeginUpdate()
    $listview_Apps.Items.Clear()
    foreach($ListItem in $ListItems) {
        $listview_Apps.Items.Add($ListItem[1])
    }
    $listview_Apps.EndUpdate()
    Write-Host "End Update"
}

Function ReRegisterApp{

    # Since we allowed 'MultiSelect = $true' on the listView control,
    # Compile a list in an array of selected items
    $SelectedProcesses = @($listview_Apps.SelectedIndices)

    # Find which column index has an the name 'Id' on it, for the listView control
    # We chose 'Id' because it is required by 'Stop-Process' to properly identify the process to kill.
    $InstallLocationColumnIndex = ($listview_Apps.Columns | Where {$_.Text -eq "InstallLocation"}).Index
    
    # For each object/item in the array of selected item, find which SubItem/cell of the row...
    $SelectedProcesses | ForEach-Object {
    
        # ...contains the Id of the process that is currently being "foreach'd",
        $InstallLocation = ($listview_Apps.Items[$_].SubItems[$InstallLocationColumnIndex]).Text

        Write-Host "Started"
        Write-Host "Install Location - $($InstallLocation)"
        Write-Host "Executing Command: 'Add-AppxPackage -DisableDevelopmentMode -Register" +  "$($InstallLocation)\AppXManifest.xml'" | Out-String

        $success = $false

        $exec = Add-AppxPackage -DisableDevelopmentMode -Register "$($InstallLocation)\AppXManifest.xml" | Out-String
        If($?) {
            $success = $true
            [System.Windows.Forms.MessageBox]::Show('The app has been re-register successfully','App Re-Register Successful')
            Write-Host "Successful"
        } ElseIf($error) {
            $err = $error[0]
            [System.Windows.Forms.MessageBox]::Show("Failed $($error[0])",'ERROR')
            Write-Host "Error"
        }
        $job = Start-Job { 
            $exec
        }
        Wait-Job $job | Out-Null
        Receive-Job $job
        Write-Host "Finished"
        
        # ...and stop it.
        #Stop-Process -Id $ProcessId -Confirm:$false -Force -WhatIf

        # The WhatIf switch was used to simulate the action. Remove it to use cmdlet as per normal.

    }

    # Refresh your process list, once you are done stopping them
    #GetApps
    
}

Function EndProcesses{

    # Since we allowed 'MultiSelect = $true' on the listView control,
    # Compile a list in an array of selected items
    $SelectedProcesses = @($listview_Apps.SelectedIndices)

    # Find which column index has an the name 'Id' on it, for the listView control
    # We chose 'Id' because it is required by 'Stop-Process' to properly identify the process to kill.
    $IdColumnIndex = ($listview_Apps.Columns | Where {$_.Text -eq "Id"}).Index
    
    # For each object/item in the array of selected item, find which SubItem/cell of the row...
    $SelectedProcesses | ForEach-Object {
    
        # ...contains the Id of the process that is currently being "foreach'd",
        $ProcessId = ($listview_Apps.Items[$_].SubItems[$IdColumnIndex]).Text
        
        # ...and stop it.
        Stop-Process -Id $ProcessId -Confirm:$false -Force -WhatIf

        # The WhatIf switch was used to simulate the action. Remove it to use cmdlet as per normal.

    }

    # Refresh your process list, once you are done stopping them
    GetApps
    
}


# Drawing form and controls
$Form_HelloWorld = New-Object System.Windows.Forms.Form
    $Form_HelloWorld.Text = "Microsoft Store App Re-Register(er)"
    $Form_HelloWorld.Size = New-Object System.Drawing.Size(832,590)
    $Form_HelloWorld.FormBorderStyle = "FixedDialog"
    $Form_HelloWorld.TopMost  = $true
    $Form_HelloWorld.MaximizeBox  = $true
    $Form_HelloWorld.MinimizeBox  = $true
    $Form_HelloWorld.ControlBox = $true
    $Form_HelloWorld.StartPosition = "CenterScreen"
    $Form_HelloWorld.Font = "Segoe UI"


# Adding a label control to Form
$label_Search = New-Object System.Windows.Forms.Label
    $label_Search.Location = New-Object System.Drawing.Size(8,8)
    $label_Search.Size = New-Object System.Drawing.Size(240,32)
    $label_Search.TextAlign = "MiddleLeft"
    $label_Search.Text = "Search:"
        $Form_HelloWorld.Controls.Add($label_Search)

# Add a Search Field
$field_Search = New-Object System.Windows.Forms.TextBox
    $field_Search.Location = New-Object System.Drawing.Size(8,40)
    $field_Search.Size = New-Object System.Drawing.Size(520,32)
    #$field_Search.TextAlign = "MiddleLeft"
    $field_Search.Text = "Search"
    $field_Search.Enabled = $true
        $Form_HelloWorld.Controls.Add($field_Search)

# Adding a label control to Form
$label_HelloWorld = New-Object System.Windows.Forms.Label
    $label_HelloWorld.Location = New-Object System.Drawing.Size(8,60)
    $label_HelloWorld.Size = New-Object System.Drawing.Size(240,32)
    $label_HelloWorld.TextAlign = "MiddleLeft"
    $label_HelloWorld.Text = "App List:"
        $Form_HelloWorld.Controls.Add($label_HelloWorld)


# Adding a listView control to Form, which will hold all process information
$Global:listview_Apps = New-Object System.Windows.Forms.ListView
    $listview_Apps.Location = New-Object System.Drawing.Size(8,92)
    $listview_Apps.Size = New-Object System.Drawing.Size(800,402)
    $listview_Apps.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Right -bor 
    [System.Windows.Forms.AnchorStyles]::Top -bor
    [System.Windows.Forms.AnchorStyles]::Left
    $listview_Apps.View = "Details"
    $listview_Apps.FullRowSelect = $true
    $listview_Apps.MultiSelect = $true
    $listview_Apps.Sorting = "None"
    $listview_Apps.AllowColumnReorder = $true
    $listview_Apps.GridLines = $true
    $listview_Apps.Add_ColumnClick({SortListView $_.Column})
        $Form_HelloWorld.Controls.Add($listview_Apps)


# Adding a button control to Form
$button_GetApps = New-Object System.Windows.Forms.Button
    $button_GetApps.Location = New-Object System.Drawing.Size(8,502)
    $button_GetApps.Size = New-Object System.Drawing.Size(240,32)
    $button_GetApps.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Left
    $button_GetApps.TextAlign = "MiddleCenter"
    $button_GetApps.Text = "Refresh App List"
    $button_GetApps.Add_Click({GetApps})
        $Form_HelloWorld.Controls.Add($button_GetApps)


# Adding another button control to Form
#$button_EndProcess = New-Object System.Windows.Forms.Button
    #$button_EndProcess.Location = New-Object System.Drawing.Size(568,450)
    #$button_EndProcess.Size = New-Object System.Drawing.Size(240,32)
    #$button_EndProcess.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor
    #[System.Windows.Forms.AnchorStyles]::Right
    #$button_EndProcess.TextAlign = "MiddleCenter"
    #$button_EndProcess.Text = "End Selected Process(es)"
    #$button_EndProcess.Add_Click({EndProcesses})
        #$Form_HelloWorld.Controls.Add($button_EndProcess)


# Adding another button control to Form
$button_ReRegisterApp = New-Object System.Windows.Forms.Button
    $button_ReRegisterApp.Location = New-Object System.Drawing.Size(568,502)
    $button_ReRegisterApp.Size = New-Object System.Drawing.Size(240,32)
    $button_ReRegisterApp.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor
    [System.Windows.Forms.AnchorStyles]::Right
    $button_ReRegisterApp.TextAlign = "MiddleCenter"
    $button_ReRegisterApp.Text = "Re-Register App(s)"
    $button_ReRegisterApp.Add_Click({ReRegisterApp})
        $Form_HelloWorld.Controls.Add($button_ReRegisterApp)



# Show form with all of its controls
$Form_HelloWorld.Add_Shown({$Form_HelloWorld.Activate();GetApps})
[Void] $Form_HelloWorld.ShowDialog()
