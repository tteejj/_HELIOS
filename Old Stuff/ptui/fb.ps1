# Terminal File Browser for PowerShell

#region State Variables
$script:FB_CurrentPath = $null
$script:FB_SelectedItems = @{}
$script:FB_Clipboard = @{ Items = @(); Action = "Copy" }
$script:FB_SortBy = "Name"
$script:FB_ShowHidden = $false
$script:FB_ViewMode = "Details"
$script:FB_SelectedIndex = 0
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
    $script:FB_SelectedIndex = 0

    $originalTitle = $Host.UI.RawUI.WindowTitle
    $Host.UI.RawUI.WindowTitle = "File Browser: $($script:FB_CurrentPath.FullName)"
    
    $result = $null
    try {
        if ($SelectFileMode -or $SelectFolderMode) {
            $result = FB_MainLoop -SelectFileMode:$SelectFileMode -SelectFolderMode:$SelectFolderMode
        } else {
            FB_MainLoop
        }
    }
    finally {
        $Host.UI.RawUI.WindowTitle = $originalTitle
    }
    return $result
}

function FB_MainLoop {
    param($SelectFileMode, $SelectFolderMode)

    while ($true) {
        $items = Get-ChildItem -LiteralPath $script:FB_CurrentPath.FullName -Force:$script:FB_ShowHidden -ErrorAction SilentlyContinue | FB_SortItems
        
        Clear-Host
        FB_ShowHeader -SelectMode:($SelectFileMode -or $SelectFolderMode)
        FB_ShowFileList -Items $items
        FB_ShowStatusBar -Items $items

        $action = FB_GetAction
        
        switch ($action.Type) {
            "Exit" { return $null }
            "Refresh" { continue }
            "Navigate" { $script:FB_CurrentPath = Get-Item -LiteralPath $action.Path; $script:FB_SelectedItems = @{}; $script:FB_SelectedIndex = 0 }
            "Open" {
                if ($SelectFileMode -and -not $action.Item.PSIsContainer) { return $action.Item.FullName }
                if ($SelectFolderMode -and $action.Item.PSIsContainer) { return $action.Item.FullName }
                if ($action.Item.PSIsContainer) { $script:FB_CurrentPath = $action.Item; $script:FB_SelectedItems = @{}; $script:FB_SelectedIndex = 0 }
                else { try { Start-Process -FilePath $action.Item.FullName } catch { Write-Warning "Could not open file: $_" } }
            }
            "ReturnPath" { return $action.Path }
            "Invoke" { & $action.Action; Start-Sleep -Milliseconds 500 } # Pause after action
        }
    }
}
#endregion

#region UI Display Functions

function FB_ShowHeader {
    param($SelectMode)
    $pathColor = Get-ThemeProperty 'Palette.WarningFG'
    Write-Header "File Browser"
    Write-Host " 📍 Path: " -ForegroundColor $pathColor -NoNewline
    Write-Host $script:FB_CurrentPath.FullName -ForegroundColor White
    if($SelectMode) { Write-Host "`n 🎯 SELECTION MODE: Press Enter on a file/folder to select and exit." -ForegroundColor (Get-ThemeProperty 'Palette.InfoFG')}
}

function FB_ShowFileList {
    param($Items)
    switch ($script:FB_ViewMode) {
        "Details" { FB_ShowDetailView -Items $Items }
        default { FB_ShowDetailView -Items $Items }
    }
}

function FB_ShowDetailView {
    param ($Items)
    $headers = @(
        @{ T = " "; W = 1 }, # Selection
        @{ T = " "; W = 1 }, # Icon
        @{ T = "Name"; W = ($Host.UI.RawUI.WindowSize.Width - 48); Align = "Left" },
        @{ T = "Size"; W = 12; Align = "Right" },
        @{ T = "Modified"; W = 19; Align = "Left" }
    )
    $headerString = ""
    foreach ($h in $headers) { $headerString += "{0,-$($h.W)} " -f $h.T }
    Write-Host "`n$headerString" -ForegroundColor (Get-ThemeProperty 'Palette.HeaderFG')
    
    # Parent directory
    if ($script:FB_CurrentPath.Parent) {
        if ($script:FB_SelectedIndex -eq -1) { Write-Host ">" -ForegroundColor (Get-ThemeProperty 'Palette.WarningFG') -NoNewline } else { Write-Host " " -NoNewline }
        Write-Host " 📁 .. " -ForegroundColor (Get-ThemeProperty 'Palette.AccentFG')
    }

    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $isSelected = $script:FB_SelectedItems.ContainsKey($item.FullName)
        $isCurrent = ($i -eq $script:FB_SelectedIndex)

        # Selection Indicator
        if ($isCurrent) { Write-Host ">" -ForegroundColor (Get-ThemeProperty 'Palette.WarningFG') -NoNewline } else { Write-Host " " -NoNewline }
        # Checkbox
        if ($isSelected) { Write-Host "[✓] " -ForegroundColor (Get-ThemeProperty 'Palette.SuccessFG') -NoNewline } else { Write-Host "[ ] " -NoNewline }
        
        # Icon and Name
        $nameColor = if ($item.PSIsContainer) { Get-ThemeProperty 'Palette.InfoFG' } else { "White" }
        $icon = Get-FileIcon $item.Extension
        Write-Host "$icon " -NoNewline
        $name = if ($item.Name.Length -gt $headers[2].W - 3) { $item.Name.Substring(0, $headers[2].W - 3) + "..." } else { $item.Name }
        Write-Host ("{0,-$($headers[2].W - 2)}" -f $name) -ForegroundColor $nameColor -NoNewline
        
        # Size
        $size = if ($item.PSIsContainer) { "<DIR>" } else { Format-FileSize $item.Length }
        Write-Host ("{0,12}" -f $size) -ForegroundColor (Get-ThemeProperty 'Palette.SubtleFG') -NoNewline

        # Date
        Write-Host "  $($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor (Get-ThemeProperty 'Palette.SubtleFG')
    }
}

function FB_ShowStatusBar {
    param ($Items)
    $width = $Host.UI.RawUI.WindowSize.Width
    Write-Host ("`n" + ("-" * $width)) -ForegroundColor (Get-ThemeProperty 'Palette.SubtleFG')
    $status = " Items: $($Items.Count) | Selected: $($script:FB_SelectedItems.Count) | Clipboard: $($script:FB_Clipboard.Items.Count) | Sort: $($script:FB_SortBy) | Hidden: $($script:FB_ShowHidden)"
    Write-Host $status -ForegroundColor (Get-ThemeProperty 'Palette.SubtleFG')
    Write-Host "[?] Help" -ForegroundColor (Get-ThemeProperty 'Palette.WarningFG')
}

#endregion

#region Actions and Logic

function FB_GetAction {
    $items = Get-ChildItem -LiteralPath $script:FB_CurrentPath.FullName -Force:$script:FB_ShowHidden -ErrorAction SilentlyContinue | FB_SortItems
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    switch ($key.VirtualKeyCode) {
        # Navigation
        38 { # Up
            if ($script:FB_SelectedIndex -gt 0) { $script:FB_SelectedIndex-- }
            elseif ($script:FB_CurrentPath.Parent) { $script:FB_SelectedIndex = -1 }
            return @{ Type = "Refresh" }
        }
        40 { # Down
            if ($script:FB_SelectedIndex -lt ($items.Count - 1)) { $script:FB_SelectedIndex++ }
            return @{ Type = "Refresh" }
        }
        37 { # Left
            if ($script:FB_CurrentPath.Parent) { return @{ Type = "Navigate"; Path = $script:FB_CurrentPath.Parent.FullName } }
            return @{ Type = "Refresh" }
        }
        13 { # Enter
            if ($script:FB_SelectedIndex -eq -1 -and $script:FB_CurrentPath.Parent) { return @{ Type = "Navigate"; Path = $script:FB_CurrentPath.Parent.FullName } }
            if ($script:FB_SelectedIndex -ge 0 -and $script:FB_SelectedIndex -lt $items.Count) { return @{ Type = "Open"; Item = $items[$script:FB_SelectedIndex] } }
            return @{ Type = "Refresh" }
        }
        # Selection
        32 { # Space
            if ($script:FB_SelectedIndex -ge 0 -and $script:FB_SelectedIndex -lt $items.Count) {
                $item = $items[$script:FB_SelectedIndex]; if ($script:FB_SelectedItems.ContainsKey($item.FullName)) { $script:FB_SelectedItems.Remove($item.FullName) } else { $script:FB_SelectedItems[$item.FullName] = $item }
            }
            if ($script:FB_SelectedIndex -lt ($items.Count - 1)) { $script:FB_SelectedIndex++ } # Move down after selection
            return @{ Type = "Refresh" }
        }
    }

    switch ($key.Character.ToString().ToLower()) {
        "q" { return @{ Type = "Exit" } }
        "?" { return @{ Type = "Invoke"; Action = { FB_ShowHelp } } }
        "c" { return @{ Type = "Invoke"; Action = { FB_CopyItems -Items $items } } }
        "v" { return @{ Type = "Invoke"; Action = { FB_PasteItems } } }
        "n" { return @{ Type = "Invoke"; Action = { FB_NewItem } } }
        "d" { return @{ Type = "Invoke"; Action = { FB_DeleteItems -Items $items } } }
        "r" { return @{ Type = "Invoke"; Action = { FB_RenameItem -Items $items } } }
        "a" { return @{ Type = "Invoke"; Action = { foreach($item in $items) { $script:FB_SelectedItems[$item.FullName] = $item } } } }
        "s" { return @{ Type = "Invoke"; Action = { FB_ToggleSort } } }
        "h" { $script:FB_ShowHidden = -not $script:FB_ShowHidden; return @{ Type = "Refresh" } }
    }
    return @{ Type = "Refresh" }
}

function FB_CopyItems {
    param($Items)
    $selected = $script:FB_SelectedItems.Values
    if ($selected.Count -eq 0 -and $script:FB_SelectedIndex -ge 0) { $selected = @($Items[$script:FB_SelectedIndex]) }
    if ($selected.Count -gt 0) { $script:FB_Clipboard.Items = @($selected.FullName); Write-Info "Copied $($selected.Count) items." }
}

function FB_PasteItems {
    if ($script:FB_Clipboard.Items.Count -eq 0) { Write-Warning "Clipboard is empty."; return }
    foreach ($source in $script:FB_Clipboard.Items) {
        $dest = Join-Path $script:FB_CurrentPath.FullName (Split-Path $source -Leaf)
        try { Copy-Item -LiteralPath $source -Destination $dest -Recurse -Force; Write-Success "Pasted: $(Split-Path $source -Leaf)" }
        catch { Write-Error "Failed to paste $(Split-Path $source -Leaf): $_" }
    }
}

function FB_DeleteItems {
    param($Items)
    $selected = $script:FB_SelectedItems.Values
    if ($selected.Count -eq 0 -and $script:FB_SelectedIndex -ge 0) { $selected = @($Items[$script:FB_SelectedIndex]) }
    if ($selected.Count -gt 0) {
        Write-Warning "Permanently delete $($selected.Count) items?"; if ((Read-Host "Type 'yes' to confirm").ToLower() -eq 'yes') {
            foreach ($item in $selected) {
                try { Remove-Item -LiteralPath $item.FullName -Recurse -Force; Write-Success "Deleted: $($item.Name)" }
                catch { Write-Error "Failed to delete $($item.Name): $_" }
            }
            $script:FB_SelectedItems.Clear()
        }
    }
}

function FB_RenameItem {
    param($Items)
    if ($script:FB_SelectedIndex -ge 0) {
        $item = $Items[$script:FB_SelectedIndex]
        $newName = Read-Host "Rename '$($item.Name)' to"
        if (-not [string]::IsNullOrWhiteSpace($newName)) {
            try { Rename-Item -LiteralPath $item.FullName -NewName $newName; Write-Success "Renamed." } catch { Write-Error "Rename failed: $_" }
        }
    }
}

function FB_NewItem {
    $type = Read-Host "[F]ile or [D]irectory?"
    $name = Read-Host "Name?"
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    $path = Join-Path $script:FB_CurrentPath.FullName $name
    $itemType = if ($type.ToLower() -eq 'd') { "Directory" } else { "File" }
    try { New-Item -Path $path -ItemType $itemType | Out-Null; Write-Success "Created $itemType '$name'." } catch { Write-Error "Failed to create: $_" }
}

function FB_ToggleSort {
    $sortOptions = @("Name", "Date", "Size", "Type")
    $current = $sortOptions.IndexOf($script:FB_SortBy)
    $next = ($current + 1) % $sortOptions.Count
    $script:FB_SortBy = $sortOptions[$next]
}

function FB_SortItems {
    param([object[]]$Items)
    switch ($script:FB_SortBy) {
        "Name" { 
            $sorted = $Items | Sort-Object PSIsContainer -Descending
            return $sorted | Sort-Object Name
        }
        "Date" { 
            $sorted = $Items | Sort-Object PSIsContainer -Descending
            return $sorted | Sort-Object LastWriteTime -Descending
        }
        "Size" { 
            $sorted = $Items | Sort-Object PSIsContainer -Descending
            return $sorted | Sort-Object Length -Descending
        }
        "Type" { 
            $sorted = $Items | Sort-Object PSIsContainer -Descending
            $sorted = $sorted | Sort-Object Extension
            return $sorted | Sort-Object Name
        }
    }
}

function FB_ShowHelp {
    Write-Header "File Browser Help"
    Write-Host @"
Key          Action
---          ------
↑/↓          Navigate files and folders
←            Go to parent directory
Enter        Open file or enter directory
Space        Select/Deselect the current item
a            Select all items in the current folder
c            Copy selected items to clipboard
v            Paste items from clipboard
d            Delete selected items (with confirmation)
r            Rename the current item
n            Create a new file or directory
s            Cycle through sort modes (Name, Date, Size, Type)
h            Toggle visibility of hidden files and folders
?            Show this help screen
q            Quit the file browser
"@
    Read-Host "`nPress Enter to continue..." | Out-Null
}

#endregion
