#If you use GreenRADIUS as a product and you have the authentication key automatically lock, really the only way to unlock it before your specified timeout is the following script. I did not write this one alone, GPT did help me but it works. I use it 
#all the time. Oh.. it put the users in a nice little table and you just have to click on them to unlock.

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Import required modules
$ErrorActionPreference = "Stop"
$hostIp = "your.greenradius.server"  # Set the hostname or IP address statically

# Function to display a popup message
function Show-MessageBox {
    param (
        [string]$Message,
        [string]$Title,
        [System.Windows.Forms.MessageBoxButtons]$Buttons,
        [System.Windows.Forms.MessageBoxIcon]$Icon
    )

    [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

# Function to show GUI table of blocked users and handle unblocking
function Show-GUIBlockedUsersTable {
    param (
        [System.Collections.ArrayList]$BlockedUsers
    )

    # Create WPF GUI
    $window = New-Object Windows.Window
    $window.Title = "Blocked Users"
    $window.Height = 350
    $window.Width = 400

    $stackPanel = New-Object Windows.Controls.StackPanel
    $stackPanel.Orientation = "Vertical"

    $dataGrid = New-Object Windows.Controls.DataGrid
    $dataGrid.AutoGenerateColumns = $false
    $dataGrid.ItemsSource = $BlockedUsers

    $column1 = New-Object Windows.Controls.DataGridTextColumn
    $column1.Header = "User"
    $column1.Binding = New-Object Windows.Data.Binding("User")

    $column2 = New-Object Windows.Controls.DataGridTextColumn
    $column2.Header = "Status"
    $column2.Binding = New-Object Windows.Data.Binding("Status")

    $dataGrid.Columns.Add($column1)
    $dataGrid.Columns.Add($column2)

    $dataGrid.Add_MouseDoubleClick({
        $selectedUser = $dataGrid.SelectedItem
        if ($selectedUser -ne $null) {
            Unblock-User -User $selectedUser.User
        }
    })

    $stackPanel.Children.Add($dataGrid)
    
    # Add a refresh button below the data grid
    $refreshButton = New-Object Windows.Controls.Button
    $refreshButton.Content = "Refresh"
    $refreshButton.Width = 100
    $refreshButton.Height = 30
    $refreshButton.HorizontalAlignment = "Left"
    $refreshButton.VerticalAlignment = "Top"
    $refreshButton.Margin = "10,5,0,0"  # Adjust top margin as needed
    $refreshButton.Add_Click({
        try {
            # Fetch the latest list of blocked users
            $response = Invoke-RestMethod -SkipCertificateCheck -Uri "https://$hostIp/gras-api/v2/mgmt/blocked-status" -Method Get -Headers @{
                'User-Agent' = 'Mozilla/something more'
                'Accept' = 'application/json'
                'Content-Type' = 'application/json'
                'Authorization' = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("grapiuser:grapipwd"))
            } -TimeoutSec 60

            $UpdatedBlockedUsers = @()

            foreach ($user in $response.PSObject.Properties) {
                if ($user.Value.status -eq "blocked") {
                    $UpdatedBlockedUsers += New-Object PSObject -Property @{
                        User = $user.Name
                        Status = $user.Value.status
                    }
                }
            }

            if ($UpdatedBlockedUsers.Count -eq 0) {
                Show-MessageBox -Message "No blocked users found." -Title "Blocked Users" -Buttons "OK" -Icon "Information"
            }
            else {
                # Show the dialog box with the updated list of blocked users
                $window.Close()
                Show-GUIBlockedUsersTable -BlockedUsers $UpdatedBlockedUsers
            }
        }
        catch {
            Show-MessageBox -Message "Error: $_" -Title "Error" -Buttons "OK" -Icon "Error"
        }
    })
    $stackPanel.Children.Add($refreshButton)

    $window.Content = $stackPanel

    ($window.ShowDialog()) | Out-Null
}

# Function to unblock a user
function Unblock-User {
    param (
        [string]$User
    )

    try {
        $url = "https://$hostIp/gras-api/v2/mgmt/unblock-users"
        $headers = @{
            'User-Agent' = 'Mozilla/something more'
            'Accept' = 'application/json'
            'Content-Type' = 'application/json'
            'Authorization' = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("grapiuser:grapipwd"))
        }
        
        $body = @{
            users = @($User)
        } | ConvertTo-Json

        $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method Put -Headers $headers -Body $body  -TimeoutSec 60

        if ($response.records_unblocked.records -contains $User) {
            Show-MessageBox -Message "User $User successfully unblocked." -Title "Unblock User" -Buttons "OK" -Icon "Information"
        }
        else {
            Show-MessageBox -Message "Failed to unblock user $User." -Title "Unblock User" -Buttons "OK" -Icon "Error"
        }
    }
    catch {
        Show-MessageBox -Message "Error: $_" -Title "Error" -Buttons "OK" -Icon "Error"
    }
}

# Main script logic
try {
    $url = "https://$hostIp/gras-api/v2/mgmt/blocked-status"
    $headers = @{
        'User-Agent' = 'Mozilla/something more'
        'Accept' = 'application/json'
        'Content-Type' = 'application/json'
        'Authorization' = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("grapiuser:grapipwd"))
    }
    
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method Get -Headers $headers -TimeoutSec 60

    $BlockedUsers = @()

    foreach ($user in $response.PSObject.Properties) {
        if ($user.Value.status -eq "blocked") {
            $BlockedUsers += New-Object PSObject -Property @{
                User = $user.Name
                Status = $user.Value.status
            }
        }
    }

    if ($BlockedUsers.Count -eq 0) {
        Show-MessageBox -Message "No blocked users found." -Title "Blocked Users" -Buttons "OK" -Icon "Information"
    }
    else {
        Show-GUIBlockedUsersTable -BlockedUsers $BlockedUsers
    }
}
catch {
    Show-MessageBox -Message "Error: $_" -Title "Error" -Buttons "OK" -Icon "Error"
}
