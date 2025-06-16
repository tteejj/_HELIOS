# Terminal File Utilities - PTUI Port
# Keyboard-centric file utilities using PTUI Framework

using namespace PoshCode.Pansies
using namespace PoshCode.TerminalUI

# Import PTUI
Import-Module PTUI -ErrorAction Stop

#region File/Directory Tools

function global:Show-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Path,
        [int]$Lines = 50,
        [switch]$All,
        [switch]$Tail
    )
    
    if (-not (Test-Path $Path)) {
        Show-PTUIMessage -Message "File not found: $Path" -Title "Error" -Color Red
        return
    }
    
    $file = Get-Item $Path
    
    if ($Tail) {
        $content = Get-Content $Path -Tail $Lines
    } elseif ($All) {
        $content = Get-Content $Path
    } else {
        $content = Get-Content $Path -TotalCount $Lines
    }
    
    $totalLines = (Get-Content $Path | Measure-Object -Line).Lines
    $displayedLines = $content.Count
    
    # Create a scrollable view
    $dialog = [Dialog]::new("File: $($file.Name)")
    
    # Add file info
    $infoText = [TextBlock]::new("Path: $($file.FullName)`nSize: $(Format-FileSize $file.Length)`nLines: $totalLines (showing $displayedLines)")
    $infoText.ForegroundColor = 'DarkGray'
    $dialog.Add($infoText)
    
    # Add content
    $contentText = [TextBlock]::new(($content -join "`n"))
    $contentText.Height = [Math]::Min(20, $content.Count + 2)
    $dialog.Add($contentText)
    
    if (-not $All -and $totalLines -gt $Lines) {
        $moreText = [TextBlock]::new("... more lines available. Use -All to see entire file")
        $moreText.ForegroundColor = 'Yellow'
        $dialog.Add($moreText)
    }
    
    $ok = [Button]::new("Close")
    $ok.IsDefault = $true
    $dialog.Add($ok)
    
    $null = Show-UI $dialog
}

function global:Find-File {
    [CmdletBinding()]
    param(
        [string]$Name = "*",
        [string]$Path = ".",
        [string]$Type = "All",
        [int]$Depth = 5,
        [switch]$Interactive
    )
    
    Show-PTUIMessage -Message "Searching for '$Name' in '$((Get-Item $Path).FullName)'..." -Title "Find File" -Color Cyan
    
    $searchParams = @{
        Path = $Path
        Recurse = $true
        ErrorAction = 'SilentlyContinue'
        Depth = $Depth
    }
    
    if ($Type -eq "File") {
        $searchParams.File = $true
    } elseif ($Type -eq "Directory") {
        $searchParams.Directory = $true
    }
    
    if ($Name -notmatch '[;\[\]]') {
        $searchParams.Filter = $Name
    } else {
        $searchParams.Include = $Name
    }
    
    $results = Get-ChildItem @searchParams
    
    if ($results.Count -eq 0) {
        Show-PTUIMessage -Message "No items found." -Title "Find File" -Color Yellow
        return
    }
    
    if ($Interactive) {
        $resultItems = $results | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                FullName = $_.FullName
                RelativePath = $_.FullName.Replace((Get-Item $Path).FullName, '.')
                IsDirectory = $_.PSIsContainer
                Size = if ($_.PSIsContainer) { "<DIR>" } else { Format-FileSize $_.Length }
                Modified = $_.LastWriteTime
                Item = $_
            }
        }
        
        $selection = [Selection]::new($resultItems, {
            param($item)
            $icon = if ($item.IsDirectory) { '📁' } else { '📄' }
            "$icon $($item.RelativePath) - $($item.Size)"
        })
        
        $selection.Title = "Found $($results.Count) items - Select to open"
        $selection.MultiSelect = $false
        
        $selected = Show-UI $selection
        
        if ($selected) {
            return $selected.Item
        }
    } else {
        $msg = "Found $($results.Count) items:`n`n"
        $results | Select-Object -First 20 | ForEach-Object {
            $icon = if ($_.PSIsContainer) { '📁' } else { '📄' }
            $msg += "$icon $($_.FullName.Replace((Get-Item $Path).FullName, '.'))`n"
        }
        if ($results.Count -gt 20) {
            $msg += "`n... and $($results.Count - 20) more items"
        }
        
        Show-PTUIMessage -Message $msg -Title "Find Results" -Color White
        return $results
    }
}

function global:Show-Tree {
    [CmdletBinding()]
    param(
        [string]$Path = ".",
        [int]$Depth = 3,
        [switch]$ShowSize,
        [switch]$ShowFiles
    )
    
    $root = Get-Item $Path
    $treeContent = @()
    
    function Get-TreeContent {
        param($Path, $Prefix = "", $CurrentDepth = 0)
        
        if ($CurrentDepth -ge $Depth) { return }
        
        $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
        $dirs = $items | Where-Object { $_.PSIsContainer }
        $files = $items | Where-Object { -not $_.PSIsContainer }
        
        for ($i = 0; $i -lt $dirs.Count; $i++) {
            $isLast = ($i -eq $dirs.Count - 1) -and ($files.Count -eq 0 -or -not $ShowFiles)
            $connector = if ($isLast) { "└── " } else { "├── " }
            
            $line = "$Prefix$connector📁 $($dirs[$i].Name)"
            if ($ShowSize) {
                $size = (Get-ChildItem -Path $dirs[$i].FullName -Recurse -File -ErrorAction SilentlyContinue | 
                         Measure-Object -Property Length -Sum).Sum
                $line += " ($(Format-FileSize $size))"
            }
            $script:treeContent += $line
            
            $newPrefix = if ($isLast -and $files.Count -eq 0) { "$Prefix    " } else { "$Prefix│   " }
            Get-TreeContent -Path $dirs[$i].FullName -Prefix $newPrefix -CurrentDepth ($CurrentDepth + 1)
        }
        
        if ($ShowFiles) {
            for ($i = 0; $i -lt $files.Count; $i++) {
                $isLast = ($i -eq $files.Count - 1)
                $connector = if ($isLast) { "└── " } else { "├── " }
                
                $line = "$Prefix$connector📄 $($files[$i].Name)"
                if ($ShowSize) {
                    $line += " ($(Format-FileSize $files[$i].Length))"
                }
                $script:treeContent += $line
            }
        }
    }
    
    $script:treeContent = @("📂 $($root.FullName)")
    Get-TreeContent -Path $Path
    
    $stats = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    $dirCount = ($stats | Where-Object { $_.PSIsContainer }).Count
    $fileCount = ($stats | Where-Object { -not $_.PSIsContainer }).Count
    $totalSize = ($stats | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
    
    $script:treeContent += ""
    $script:treeContent += "Summary: $dirCount directories, $fileCount files, $(Format-FileSize $totalSize)"
    
    # Display in a dialog
    $dialog = [Dialog]::new("Directory Tree: $($root.Name)")
    
    $treeText = [TextBlock]::new(($script:treeContent -join "`n"))
    $treeText.Height = [Math]::Min(25, $script:treeContent.Count + 2)
    $dialog.Add($treeText)
    
    $ok = [Button]::new("Close")
    $ok.IsDefault = $true
    $dialog.Add($ok)
    
    $null = Show-UI $dialog
}

#endregion

#region Excel Tools

function global:Show-Excel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$Sheet = 1,
        [int]$Rows = 20,
        [int]$Columns = 10,
        [switch]$All
    )
    
    if (-not (Test-Path $Path)) {
        Show-PTUIMessage -Message "File not found: $Path" -Title "Error" -Color Red
        return
    }
    
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        $workbook = $excel.Workbooks.Open($Path)
        
        # Create sheet selection
        $sheetItems = @()
        for ($i = 1; $i -le $workbook.Worksheets.Count; $i++) {
            $ws = $workbook.Worksheets.Item($i)
            $sheetItems += [PSCustomObject]@{
                Index = $i
                Name = $ws.Name
            }
        }
        
        $selectedSheet = if ($Sheet -is [int]) {
            $workbook.Worksheets.Item($Sheet)
        } else {
            $selection = [Selection]::new($sheetItems, { "[$($_.Index)] $($_.Name)" })
            $selection.Title = "Select Sheet"
            $selection.MultiSelect = $false
            
            $result = Show-UI $selection
            if ($result) {
                $workbook.Worksheets.Item($result.Index)
            } else {
                $workbook.Close($false)
                $excel.Quit()
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
                return
            }
        }
        
        $worksheet = $selectedSheet
        $usedRange = $worksheet.UsedRange
        $maxRows = if ($All) { $usedRange.Rows.Count } else { [Math]::Min($Rows, $usedRange.Rows.Count) }
        $maxCols = if ($All) { $usedRange.Columns.Count } else { [Math]::Min($Columns, $usedRange.Columns.Count) }
        
        # Build table data
        $tableData = @()
        for ($row = 1; $row -le $maxRows; $row++) {
            $rowData = @()
            for ($col = 1; $col -le $maxCols; $col++) {
                $cellValue = $worksheet.Cells.Item($row, $col).Text
                $rowData += if ($cellValue.Length -gt 15) { $cellValue.Substring(0, 12) + "..." } else { $cellValue }
            }
            $tableData += [PSCustomObject]@{
                Row = $row
                Data = $rowData -join " | "
            }
        }
        
        # Display in dialog
        $dialog = [Dialog]::new("Excel: $(Split-Path $Path -Leaf) - Sheet: $($worksheet.Name)")
        
        $infoText = [TextBlock]::new("Sheet: $($worksheet.Name)`nUsed Range: $($usedRange.Rows.Count) rows x $($usedRange.Columns.Count) columns`nShowing: $maxRows rows x $maxCols columns")
        $infoText.ForegroundColor = 'DarkGray'
        $dialog.Add($infoText)
        
        $dataText = [TextBlock]::new(($tableData | ForEach-Object { "[$($_.Row)] $($_.Data)" }) -join "`n")
        $dataText.Height = [Math]::Min(20, $tableData.Count + 2)
        $dialog.Add($dataText)
        
        $ok = [Button]::new("Close")
        $ok.IsDefault = $true
        $dialog.Add($ok)
        
        $null = Show-UI $dialog
        
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        
    } catch {
        Show-PTUIMessage -Message "Excel Error: $_" -Title "Error" -Color Red
    }
}

#endregion

#region Fuzzy Text Search

function global:Search-FuzzyText {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$SearchTerm,
        [Parameter(Position=1)]
        [string]$Path,
        [int]$MinSimilarity = 60,
        [int]$ContextLines = 2,
        [switch]$CaseSensitive,
        [switch]$Interactive,
        [string]$Pattern = "*.txt",
        [int]$MaxResults = 50
    )
    
    if (-not $Path) {
        # Use file browser to select file
        $Path = Start-TerminalFileBrowser -SelectFileMode
        if (-not $Path) {
            Show-PTUIMessage -Message "Search cancelled." -Title "Fuzzy Search" -Color Yellow
            return
        }
    }
    
    if (-not $SearchTerm) {
        $dialog = [Dialog]::new("Fuzzy Text Search")
        
        $fileLabel = [TextBlock]::new("File: $((Get-Item $Path).Name)")
        $fileLabel.ForegroundColor = 'DarkGray'
        $dialog.Add($fileLabel)
        
        $searchLabel = [TextBlock]::new("Enter search term:")
        $searchInput = [TextBox]::new()
        $dialog.Add($searchLabel)
        $dialog.Add($searchInput)
        
        $ok = [Button]::new("Search")
        $ok.IsDefault = $true
        $cancel = [Button]::new("Cancel")
        $cancel.IsCancel = $true
        $dialog.Add($ok)
        $dialog.Add($cancel)
        
        $result = Show-UI $dialog
        
        if ($result -ne 0 -or [string]::IsNullOrWhiteSpace($searchInput.Text)) {
            Show-PTUIMessage -Message "Search cancelled." -Title "Fuzzy Search" -Color Yellow
            return
        }
        
        $SearchTerm = $searchInput.Text
    }
    
    $matches = Find-FuzzyMatches -FilePath $Path -SearchTerm $SearchTerm -MinSimilarity $MinSimilarity -ContextLines $ContextLines -CaseSensitive:$CaseSensitive -MaxResults $MaxResults
    
    if ($matches.Count -eq 0) {
        Show-PTUIMessage -Message "No matches found." -Title "Fuzzy Search" -Color Yellow
        return
    }
    
    if ($Interactive) {
        $matchItems = $matches | ForEach-Object {
            [PSCustomObject]@{
                LineNumber = $_.LineNumber
                Line = $_.Line
                Similarity = $_.Similarity
                Context = $_.Context
                Display = "Line $($_.LineNumber) ($($_.Similarity)%): $($_.Line)"
            }
        }
        
        $selection = [Selection]::new($matchItems, { $_.Display })
        $selection.Title = "Found $($matches.Count) matches - Select to view details"
        $selection.MultiSelect = $true
        
        $selected = Show-UI $selection
        
        if ($selected) {
            foreach ($match in $selected) {
                $details = @"
File: $($match.FileName)
Line: $($match.LineNumber)
Similarity: $($match.Similarity)%

Context:
"@
                $match.Context.Before | ForEach-Object {
                    $details += "`n  $($_.LineNumber): $($_.Text)"
                }
                $details += "`n→ $($match.LineNumber): $($match.Line)"
                $match.Context.After | ForEach-Object {
                    $details += "`n  $($_.LineNumber): $($_.Text)"
                }
                
                Show-PTUIMessage -Message $details -Title "Match Details" -Color White
            }
        }
    } else {
        $msg = "Found $($matches.Count) matches:`n`n"
        $matches | Select-Object -First 10 | ForEach-Object {
            $msg += "Line $($_.LineNumber) ($($_.Similarity)%): $($_.Line)`n"
        }
        if ($matches.Count -gt 10) {
            $msg += "`n... and $($matches.Count - 10) more matches"
        }
        
        Show-PTUIMessage -Message $msg -Title "Fuzzy Search Results" -Color White
    }
    
    return $matches
}

function global:Find-FuzzyMatches {
    param(
        [string]$FilePath,
        [string]$SearchTerm,
        [int]$MinSimilarity,
        [int]$ContextLines,
        [bool]$CaseSensitive,
        [int]$MaxResults
    )
    
    $content = Get-Content $FilePath
    $matches = @()
    
    for ($i = 0; $i -lt $content.Count; $i++) {
        $line = $content[$i]
        $similarity = Get-FuzzySimilarity -String1 $line -String2 $SearchTerm -CaseSensitive:$CaseSensitive
        
        if ($similarity -ge $MinSimilarity) {
            $context = Get-Context -Content $content -LineNumber $i -ContextLines $ContextLines
            $matches += [PSCustomObject]@{
                LineNumber = $i + 1
                Line = $line
                Similarity = $similarity
                Context = $context
                Type = "FullLine"
                FileName = Split-Path $FilePath -Leaf
            }
        }
    }
    
    return $matches | Sort-Object Similarity -Descending | Select-Object -First $MaxResults
}

function global:Get-FuzzySimilarity {
    param(
        [string]$String1,
        [string]$String2,
        [bool]$CaseSensitive
    )
    
    if (-not $CaseSensitive) {
        $String1 = $String1.ToLower()
        $String2 = $String2.ToLower()
    }
    
    # Simple similarity calculation based on common characters
    $commonChars = 0
    $searchChars = $String2.ToCharArray()
    
    foreach ($char in $searchChars) {
        if ($String1.Contains($char)) {
            $commonChars++
        }
    }
    
    # Check for substring match
    if ($String1.Contains($String2)) {
        return 100
    }
    
    # Calculate similarity percentage
    $similarity = [Math]::Round(($commonChars / $searchChars.Count) * 100)
    
    return $similarity
}

function global:Get-Context {
    param(
        [array]$Content,
        [int]$LineNumber,
        [int]$ContextLines
    )
    
    $context = @{
        Before = @()
        After = @()
    }
    
    for ($i = [Math]::Max(0, $LineNumber - $ContextLines); $i -lt $LineNumber; $i++) {
        $context.Before += [PSCustomObject]@{
            LineNumber = $i + 1
            Text = $Content[$i]
        }
    }
    
    for ($i = $LineNumber + 1; $i -le [Math]::Min($Content.Count - 1, $LineNumber + $ContextLines); $i++) {
        $context.After += [PSCustomObject]@{
            LineNumber = $i + 1
            Text = $Content[$i]
        }
    }
    
    return $context
}

#endregion

#region Helper Functions

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

#region Help Functions

function global:Show-FileUtilsHelp {
    $helpText = @"
Terminal File Utilities (PTUI Edition)

FILE OPERATIONS:
  Show-File (sf)         - View file content with PTUI dialog
    -Path <file>         - File to display
    -Lines <n>           - Number of lines to show (default: 50)
    -All                 - Show entire file
    -Tail                - Show last lines

  Find-File (ff)         - Interactive file search
    -Name <pattern>      - File name pattern
    -Path <dir>          - Start directory
    -Type <All|File|Dir> - Item type filter
    -Interactive         - Interactive selection mode

  Search-FuzzyText (fz)  - Fuzzy search in files
    -SearchTerm <text>   - Text to search
    -Path <file>         - File to search in
    -MinSimilarity <n>   - Minimum match percentage
    -Interactive         - Interactive results

DIRECTORY TOOLS:
  Show-Tree (st)         - Tree view with stats
    -Path <dir>          - Directory to display
    -Depth <n>           - Tree depth (default: 3)
    -ShowSize            - Include sizes
    -ShowFiles           - Include files

EXCEL OPERATIONS:
  Show-Excel (se)        - View Excel files
    -Path <file>         - Excel file path
    -Sheet <n|name>      - Sheet to display
    -Rows <n>            - Rows to show
    -All                 - Show all data

KEYBOARD SHORTCUTS:
  In file browser:
    Space     - Toggle selection
    A         - Select all
    N         - Deselect all
    H         - Toggle hidden files
    S         - Cycle sort order
    
  In dialogs:
    Enter     - Accept/OK
    Escape    - Cancel
    Tab       - Next control
    Shift+Tab - Previous control
"@
    
    Show-PTUIMessage -Message $helpText -Title "File Utils Help" -Color Cyan
}

#endregion

#region Aliases

Set-Alias -Name sf -Value Show-File -Scope Global
Set-Alias -Name ff -Value Find-File -Scope Global
Set-Alias -Name st -Value Show-Tree -Scope Global
Set-Alias -Name se -Value Show-Excel -Scope Global
Set-Alias -Name fz -Value Search-FuzzyText -Scope Global
Set-Alias -Name fuh -Value Show-FileUtilsHelp -Scope Global

#endregion

Write-Host "Terminal File Utilities (PTUI) loaded. Use 'fuh' for help." -ForegroundColor Cyan
