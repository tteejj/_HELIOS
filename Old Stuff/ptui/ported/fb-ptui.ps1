# Terminal File Browser - PTUI Port
# Keyboard-centric file browser using PTUI Framework

using namespace PoshCode.Pansies
using namespace PoshCode.TerminalUI

# Import PTUI
Import-Module PTUI -ErrorAction Stop

#region State Variables
$script:FB_CurrentPath = $null
$script:FB_SelectedItems = @{}
$script:FB_Clipboard = @{ Items = @(); Action = "Copy" }
$script:FB_SortBy = "Name"
$script:FB_ShowHidden = $false
#endregion

#region Main Entry Points

function global:Start-TerminalFileBrowser {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location).Path,
        [switch]$SelectFileMode,
        [switch]$SelectFolderMode
    )
    
    $script:FB_CurrentPath = Get-Item -LiteralPath $Path
    $script:FB_SelectedItems = @{}
    
    return FB_MainLoop -SelectFileMode:$SelectFileMode -SelectFolderMode:$SelectFolderMode
}

function FB_MainLoop {
    param($SelectFileMode, $SelectFolderMode)

    while ($true) {
        $items = Get-ChildItem -LiteralPath $script:FB_CurrentPath.FullName -Force:$script:FB_ShowHidden -ErrorAction SilentlyContinue | FB_SortItems
        
        # Create menu items for file list
        $menuItems = @()
        
        # Add parent directory option if available
        if ($script:FB_CurrentPath.Parent) {
            $menuItems += [PSCustomObject]@{
                Type = "Parent"
                Name = ".."
                FullName = $script:FB_CurrentPath.Parent.FullName
                IsDirectory = $true
                Icon = "📁"
            }
        }
        
        # Add current directory items
        foreach ($item in $items) {
            $icon = if ($item.PSIsContainer) { "📁" } else { Get-FileIcon $item.Extension }
            $size = if ($item.PSIsContainer) { "<DIR>" } else { Format-FileSize $item.Length }
            
            $menuItems += [PSCustomObject]@{
                Type = "Item"
                Name = $item.Name
                FullName = $item.FullName
                IsDirectory = $item.PSIsContainer
                Size = $size
                Modified = $item.LastWriteTime
                Icon = $icon
                Item = $item
            }
        }
        
        # Add action options at the bottom
        $menuItems += [PSCustomObject]@{
            Type = "Action"
            Name = "[Actions Menu]"
            Action = "ShowActions"
        }
        
        $menuItems += [PSCustomObject]@{
            Type = "Action"
            Name = "[Exit]"
            Action = "Exit"
        }
        
        # Create the selection
        $selection = [Selection]::new($menuItems, {
            param($item)
            switch ($item.Type) {
                "Parent" { return "↑ .. (Parent Directory)" }
                "Item" {
                    $selected = if ($script:FB_SelectedItems.ContainsKey($item.FullName)) { "✓" } else { " " }
                    $size = if ($item.IsDirectory) { "<DIR>" } else { $item.Size }
                    return "$selected $($item.Icon) $($item.Name) - $size"
                }
                "Action" { return $item.Name }
            }
        })
        
        $selection.Title = "📂 $($script:FB_CurrentPath.FullName)"
        $selection.MultiSelect = $false
        
        # Handle keyboard shortcuts
        $selection.KeyBindings = @{
            ' ' = {
                # Space - toggle selection
                $currentItem = $_.SelectedItem
                if ($currentItem.Type -eq "Item") {
                    if ($script:FB_SelectedItems.ContainsKey($currentItem.FullName)) {
                        $script:FB_SelectedItems.Remove($currentItem.FullName)
                    } else {
                        $script:FB_SelectedItems[$currentItem.FullName] = $currentItem.Item
                    }
                    $_.Refresh()
                }
            }
            'a' = {
                # Select all
                foreach ($item in $menuItems | Where-Object { $_.Type -eq "Item" }) {
                    $script:FB_SelectedItems[$item.FullName] = $item.Item
                }
                $_.Refresh()
            }
            'n' = {
                # Deselect all
                $script:FB_SelectedItems.Clear()
                $_.Refresh()
            }
            'h' = {
                # Toggle hidden files
                $script:FB_ShowHidden = -not $script:FB_ShowHidden
                $_.Cancel()
            }
            's' = {
                # Cycle sort
                FB_ToggleSort
                $_.Cancel()
            }
        }
        
        $result = Show-UI $selection
        
        if ($null -eq $result) {
            # Refresh needed (sort or hidden changed)
            continue
        }
        
        $selected = $result
        
        switch ($selected.Type) {
            "Parent" {
                $script:FB_CurrentPath = Get-Item -LiteralPath $selected.FullName
                $script:FB_SelectedItems.Clear()
            }
            "Item" {
                if ($SelectFileMode -and -not $selected.IsDirectory) {
                    return $selected.FullName
                }
                if ($SelectFolderMode -and $selected.IsDirectory) {
                    return $selected.FullName
                }
                if ($selected.IsDirectory) {
                    $script:FB_CurrentPath = Get-Item -LiteralPath $selected.FullName
                    $script:FB_SelectedItems.Clear()
                } else {
                    # Open file
                    try {
                        Start-Process -FilePath $selected.FullName
                    } catch {
                        Show-PTUIMessage -Message "Could not open file: $_" -Title "Error" -Color Red
                    }
                }
            }
            "Action" {
                switch ($selected.Action) {
                    "ShowActions" {
                        $actionResult = Show-FileActions
                        if ($actionResult -eq "Exit") {
                            return $null
                        }
                    }
                    "Exit" {
                        return $null
                    }
                }
            }
        }
    }
}

#endregion

#region Action Functions

function Show-FileActions {
    $actions = @(
        [PSCustomObject]@{ Key = "C"; Text = "Copy selected items"; Action = { FB_CopyItems } }
        [PSCustomObject]@{ Key = "V"; Text = "Paste items"; Action = { FB_PasteItems } }
        [PSCustomObject]@{ Key = "D"; Text = "Delete selected items"; Action = { FB_DeleteItems } }
        [PSCustomObject]@{ Key = "R"; Text = "Rename current item"; Action = { FB_RenameItem } }
        [PSCustomObject]@{ Key = "N"; Text = "New file/folder"; Action = { FB_NewItem } }
        [PSCustomObject]@{ Key = "P"; Text = "Properties"; Action = { FB_ShowProperties } }
        [PSCustomObject]@{ Key = "S"; Text = "Change sort order (Current: $script:FB_SortBy)"; Action = { FB_ToggleSort } }
        [PSCustomObject]@{ Key = "H"; Text = "Toggle hidden files (Current: $(if($script:FB_ShowHidden){'Shown'}else{'Hidden'}))"; Action = { $script:FB_ShowHidden = -not $script:FB_ShowHidden } }
        [PSCustomObject]@{ Key = "B"; Text = "Back to file list"; Action = { return "Back" } }
        [PSCustomObject]@{ Key = "Q"; Text = "Quit file browser"; Action = { return "Exit" } }
    )
    
    $selected = Show-PTUIMenu -Title "File Actions" -MenuItems $actions -ItemFormatter { "$($_.Key) - $($_.Text)" }
    
    if ($selected) {
        $result = & $selected.Action
        return $result
    }
    
    return "Back"
}

function FB_CopyItems {
    $items = Get-ChildItem -LiteralPath $script:FB_CurrentPath.FullName -Force:$script:FB_ShowHidden -ErrorAction SilentlyContinue | FB_SortItems
    $selected = $script:FB_SelectedItems.Values
    
    if ($selected.Count -eq 0) {
        # No items selected, show selection dialog
        $itemList = $items | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                FullName = $_.FullName
                IsDirectory = $_.PSIsContainer
            }
        }
        
        $selection = [Selection]::new($itemList, {
            param($item)
            $icon = if ($item.IsDirectory) { "📁" } else { "📄" }
            "$icon $($item.Name)"
        })
        
        $selection.Title = "Select items to copy"
        $selection.MultiSelect = $true
        
        $result = Show-UI $selection
        if ($result) {
            $selected = $result | ForEach-Object { Get-Item -LiteralPath $_.FullName }
        }
    }
    
    if ($selected.Count -gt 0) {
        $script:FB_Clipboard.Items = @($selected | ForEach-Object { $_.FullName })
        $script:FB_Clipboard.Action = "Copy"
        Show-PTUIMessage -Message "Copied $($selected.Count) items to clipboard." -Title "Copy" -Color Green
    }
}

function FB_PasteItems {
    if ($script:FB_Clipboard.Items.Count -eq 0) {
        Show-PTUIMessage -Message "Clipboard is empty." -Title "Paste" -Color Yellow
        return
    }
    
    $confirmed = Show-PTUIConfirm -Message "Paste $($script:FB_Clipboard.Items.Count) items here?" -Title "Confirm Paste"
    
    if ($confirmed) {
        $errors = @()
        $success = 0
        
        foreach ($source in $script:FB_Clipboard.Items) {
            if (Test-Path $source) {
                $dest = Join-Path $script:FB_CurrentPath.FullName (Split-Path $source -Leaf)
                try {
                    if ($script:FB_Clipboard.Action -eq "Cut") {
                        Move-Item -LiteralPath $source -Destination $dest -Force
                    } else {
                        Copy-Item -LiteralPath $source -Destination $dest -Recurse -Force
                    }
                    $success++
                } catch {
                    $errors += "Failed to paste $(Split-Path $source -Leaf): $_"
                }
            }
        }
        
        if ($script:FB_Clipboard.Action -eq "Cut") {
            $script:FB_Clipboard.Items = @()
        }
        
        if ($errors.Count -gt 0) {
            $errorMsg = "Pasted $success items with $($errors.Count) errors:`n" + ($errors -join "`n")
            Show-PTUIMessage -Message $errorMsg -Title "Paste Results" -Color Yellow
        } else {
            Show-PTUIMessage -Message "Successfully pasted $success items." -Title "Paste" -Color Green
        }
    }
}

function FB_DeleteItems {
    $selected = $script:FB_SelectedItems.Values
    
    if ($selected.Count -eq 0) {
        Show-PTUIMessage -Message "No items selected for deletion." -Title "Delete" -Color Yellow
        return
    }
    
    $itemList = ($selected | ForEach-Object { "- $($_.Name)" }) -join "`n"
    $confirmed = Show-PTUIConfirm -Message "Permanently delete these $($selected.Count) items?`n`n$itemList" -Title "Confirm Delete"
    
    if ($confirmed) {
        $errors = @()
        $success = 0
        
        foreach ($item in $selected) {
            try {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force
                $success++
            } catch {
                $errors += "Failed to delete $($item.Name): $_"
            }
        }
        
        $script:FB_SelectedItems.Clear()
        
        if ($errors.Count -gt 0) {
            $errorMsg = "Deleted $success items with $($errors.Count) errors:`n" + ($errors -join "`n")
            Show-PTUIMessage -Message $errorMsg -Title "Delete Results" -Color Yellow
        } else {
            Show-PTUIMessage -Message "Successfully deleted $success items." -Title "Delete" -Color Green
        }
    }
}

function FB_RenameItem {
    $items = Get-ChildItem -LiteralPath $script:FB_CurrentPath.FullName -Force:$script:FB_ShowHidden -ErrorAction SilentlyContinue | FB_SortItems
    
    if ($items.Count -eq 0) {
        Show-PTUIMessage -Message "No items to rename." -Title "Rename" -Color Yellow
        return
    }
    
    # Select item to rename
    $itemList = $items | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            FullName = $_.FullName
            IsDirectory = $_.PSIsContainer
        }
    }
    
    $selected = Show-PTUIMenu -Title "Select item to rename" -MenuItems $itemList -ItemFormatter {
        param($item)
        $icon = if ($item.IsDirectory) { "📁" } else { "📄" }
        "$icon $($item.Name)"
    }
    
    if ($selected) {
        $dialog = [Dialog]::new("Rename Item")
        
        $currentLabel = [TextBlock]::new("Current name: $($selected.Name)")
        $dialog.Add($currentLabel)
        
        $newNameLabel = [TextBlock]::new("New name:")
        $newNameInput = [TextBox]::new()
        $newNameInput.Text = $selected.Name
        $dialog.Add($newNameLabel)
        $dialog.Add($newNameInput)
        
        $ok = [Button]::new("Rename")
        $ok.IsDefault = $true
        $cancel = [Button]::new("Cancel")
        $cancel.IsCancel = $true
        $dialog.Add($ok)
        $dialog.Add($cancel)
        
        $result = Show-UI $dialog
        
        if ($result -eq 0 -and -not [string]::IsNullOrWhiteSpace($newNameInput.Text)) {
            try {
                Rename-Item -LiteralPath $selected.FullName -NewName $newNameInput.Text
                Show-PTUIMessage -Message "Successfully renamed to: $($newNameInput.Text)" -Title "Rename" -Color Green
            } catch {
                Show-PTUIMessage -Message "Rename failed: $_" -Title "Error" -Color Red
            }
        }
    }
}

function FB_NewItem {
    $dialog = [Dialog]::new("Create New Item")
    
    $typeLabel = [TextBlock]::new("Type:")
    $typeSelect = [Selection]::new(@("File", "Directory"))
    $typeSelect.MultiSelect = $false
    $dialog.Add($typeLabel)
    $dialog.Add($typeSelect)
    
    $nameLabel = [TextBlock]::new("Name:")
    $nameInput = [TextBox]::new()
    $dialog.Add($nameLabel)
    $dialog.Add($nameInput)
    
    $ok = [Button]::new("Create")
    $ok.IsDefault = $true
    $cancel = [Button]::new("Cancel")
    $cancel.IsCancel = $true
    $dialog.Add($ok)
    $dialog.Add($cancel)
    
    $result = Show-UI $dialog
    
    if ($result -eq 0 -and -not [string]::IsNullOrWhiteSpace($nameInput.Text)) {
        $itemType = if ($typeSelect.SelectedItems -and $typeSelect.SelectedItems[0] -eq "Directory") { "Directory" } else { "File" }
        $path = Join-Path $script:FB_CurrentPath.FullName $nameInput.Text
        
        try {
            New-Item -Path $path -ItemType $itemType | Out-Null
            Show-PTUIMessage -Message "Created $itemType '$($nameInput.Text)'." -Title "Success" -Color Green
        } catch {
            Show-PTUIMessage -Message "Failed to create: $_" -Title "Error" -Color Red
        }
    }
}

function FB_ShowProperties {
    $selected = $script:FB_SelectedItems.Values
    
    if ($selected.Count -eq 0) {
        # Show properties of current directory
        $item = $script:FB_CurrentPath
    } elseif ($selected.Count -eq 1) {
        $item = $selected[0]
    } else {
        # Multiple items selected
        $totalSize = ($selected | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
        $dirCount = ($selected | Where-Object { $_.PSIsContainer }).Count
        $fileCount = ($selected | Where-Object { -not $_.PSIsContainer }).Count
        
        $properties = @"
Selected Items: $($selected.Count)
Directories: $dirCount
Files: $fileCount
Total Size: $(Format-FileSize $totalSize)
"@
        
        Show-PTUIMessage -Message $properties -Title "Properties" -Color Cyan
        return
    }
    
    # Single item properties
    $properties = @"
Name: $($item.Name)
Type: $(if ($item.PSIsContainer) { "Directory" } else { "File ($($item.Extension))" })
Location: $($item.DirectoryName)
Size: $(if ($item.PSIsContainer) { 
    $size = Get-ChildItem -Path $item.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    Format-FileSize $size.Sum
} else { 
    Format-FileSize $item.Length 
})
Created: $($item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))
Modified: $($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
Attributes: $($item.Attributes)
"@
    
    Show-PTUIMessage -Message $properties -Title "Properties: $($item.Name)" -Color Cyan
}

function FB_ToggleSort {
    $sortOptions = @("Name", "Date", "Size", "Type")
    $current = $sortOptions.IndexOf($script:FB_SortBy)
    $next = ($current + 1) % $sortOptions.Count
    $script:FB_SortBy = $sortOptions[$next]
}

#endregion

#region Helper Functions

function FB_SortItems {
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$Items
    )
    
    process {
        switch ($script:FB_SortBy) {
            "Name" { 
                $Items | Sort-Object PSIsContainer -Descending | Sort-Object Name
            }
            "Date" { 
                $Items | Sort-Object PSIsContainer -Descending | Sort-Object LastWriteTime -Descending
            }
            "Size" { 
                $Items | Sort-Object PSIsContainer -Descending | Sort-Object Length -Descending
            }
            "Type" { 
                $Items | Sort-Object PSIsContainer -Descending | Sort-Object Extension | Sort-Object Name
            }
        }
    }
}

function Get-FileIcon {
    param([string]$Extension)
    
    switch ($Extension.ToLower()) {
        { $_ -in '.txt', '.log', '.md' } { '📄' }
        { $_ -in '.ps1', '.psm1', '.psd1' } { '📜' }
        { $_ -in '.exe', '.msi', '.bat', '.cmd' } { '⚙️' }
        { $_ -in '.zip', '.rar', '.7z', '.tar', '.gz' } { '📦' }
        { $_ -in '.jpg', '.jpeg', '.png', '.gif', '.bmp' } { '🖼️' }
        { $_ -in '.mp3', '.wav', '.flac', '.aac' } { '🎵' }
        { $_ -in '.mp4', '.avi', '.mkv', '.mov' } { '🎬' }
        { $_ -in '.doc', '.docx', '.odt' } { '📝' }
        { $_ -in '.xls', '.xlsx', '.ods' } { '📊' }
        { $_ -in '.pdf' } { '📕' }
        { $_ -in '.html', '.htm', '.css', '.js' } { '🌐' }
        { $_ -in '.xml', '.json', '.yaml', '.yml' } { '📋' }
        default { '📄' }
    }
}

function Format-FileSize {
    param([long]$Size)
    
    if ($Size -eq 0) { return "0 B" }
    
    $units = @("B", "KB", "MB", "GB", "TB")
    $unitIndex = 0
    $sizeDouble = [double]$Size
    
    while ($sizeDouble -ge 1024 -and $unitIndex -lt $units.Count - 1) {
        $sizeDouble /= 1024
        $unitIndex++
    }
    
    if ($unitIndex -eq 0) {
        return "$Size B"
    } else {
        return "{0:N2} {1}" -f $sizeDouble, $units[$unitIndex]
    }
}

function Show-PTUIMessage {
    param(
        [string]$Message,
        [string]$Title = "Information",
        [ConsoleColor]$Color = 'White'
    )
    
    $dialog = [Dialog]::new($Title)
    $text = [TextBlock]::new($Message)
    $text.ForegroundColor = $Color
    $dialog.Add($text)
    
    $ok = [Button]::new("OK")
    $ok.IsDefault = $true
    $dialog.Add($ok)
    
    $null = Show-UI $dialog
}

function Show-PTUIMenu {
    param(
        [string]$Title,
        [array]$MenuItems,
        [scriptblock]$ItemFormatter = { $_ }
    )
    
    $selection = [Selection]::new($MenuItems, $ItemFormatter)
    $selection.Title = $Title
    $selection.MultiSelect = $false
    
    $result = Show-UI $selection
    return $result
}

function Show-PTUIConfirm {
    param(
        [string]$Message,
        [string]$Title = "Confirm"
    )
    
    $dialog = [Dialog]::new($Title)
    $text = [TextBlock]::new($Message)
    $dialog.Add($text)
    
    $yes = [Button]::new("Yes")
    $yes.IsDefault = $true
    $no = [Button]::new("No")
    $no.IsCancel = $true
    
    $dialog.Add($yes)
    $dialog.Add($no)
    
    $result = Show-UI $dialog
    return $result -eq 0  # Yes was selected
}

#endregion

# Create aliases
Set-Alias -Name fb -Value Start-TerminalFileBrowser -Scope Global

Write-Host "Terminal File Browser (PTUI) loaded. Use 'fb' or 'Start-TerminalFileBrowser' to start." -ForegroundColor Cyan
