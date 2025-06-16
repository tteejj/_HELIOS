#Region '.\Init\0.ps1' 0
using namespace PoshCode.Pansies

$BoxChars = [PSCustomObject]@{
    'HorizontalDouble'           = ([char]9552).ToString()
    'VerticalDouble'             = ([char]9553).ToString()
    'TopLeftDouble'              = ([char]9556).ToString()
    'TopRightDouble'             = ([char]9559).ToString()
    'BottomLeftDouble'           = ([char]9562).ToString()
    'BottomRightDouble'          = ([char]9565).ToString()
    'HorizontalDoubleSingleDown' = ([char]9572).ToString()
    'HorizontalDoubleSingleUp'   = ([char]9575).ToString()
    'Horizontal'                 = ([char]9472).ToString()
    'Vertical'                   = ([char]9474).ToString()
    'TopLeft'                    = ([char]9484).ToString()
    'TopRight'                   = ([char]9488).ToString()
    'BottomLeft'                 = ([char]9492).ToString()
    'BottomRight'                = ([char]9496).ToString()
    'Cross'                      = ([char]9532).ToString()
    'VerticalDoubleRightSingle'  = ([char]9567).ToString()
    'VerticalDoubleRightDouble'  = ([char]9568).ToString()
    'VerticalDoubleLeftSingle'   = ([char]9570).ToString()
    'VerticalDoubleLeftDouble'   = ([char]9571).ToString()
}

$EscapeRegex = [Regex]::new("[\u001B\u009B][[\]()#;?]*(?:(?:(?:[a-zA-Z\d]*(?:;[a-zA-Z\d]*)*)?\u0007)|(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PRZcf-ntqry=><~]))")

$e = "$([char]27)"

$Up    = "$e[A"         # Cursor Up 	Cursor up by {0}
$Down  = "$e[B"         # Cursor Down 	Cursor down by {0}
$Right = "$e[C"         # Cursor Forward 	Cursor forward (Right) by {0}
$Left  = "$e[D"         # Cursor Backward 	Cursor backward (Left) by {0}

$UpN   = "$e[{0}A"      # Cursor Up 	Cursor up by {0}
$DownN = "$e[{0}B"      # Cursor Down 	Cursor down by {0}
$RightN= "$e[{0}C"      # Cursor Forward 	Cursor forward (Right) by {0}
$LeftN = "$e[{0}D"      # Cursor Backward 	Cursor backward (Left) by {0}

$CRF   = "$e[{0}E"      # Cursor Next Line 	Cursor down to beginning of {0}th line in the viewport
$CRB   = "$e[{0}F"      # Cursor Previous Line 	Cursor up to beginning of {0}th line in the viewport
$SetX  = "$e[{0}G"      # Cursor Horizontal Absolute 	Cursor moves to {0}th position horizontally in the current line
$SetY  = "$e[{0}d"      # Vertical Line Position Absolute 	Cursor moves to the {0}th position vertically in the current column
$SetXY = "$e[{1};{0}H"  # Cursor Position 	*Cursor moves to {1}; {0} coordinate within the viewport, where {0} is the column of the {1} line
# $SetXY = "$e[{0};{1}f"  # Horizontal Vertical Position 	*Cursor moves to {1}; {0} coordinate within the viewport, where {1} is the column of the {0} line
$Save  = "$e[s"         # Save Cursor - Ansi.sys emulation 	**With no parameters, performs a save cursor operation like DECSC
$Load  = "$e[u"         # Restore Cursor - Ansi.sys emulation 	**With no parameters, performs a restore cursor operation like DECRC
$Show  = "$e[?25h"      # Text Cursor Enable Mode Show 	Show the cursor
$Hide  = "$e[?25l"      # Text Cursor Enable Mode Hide 	Hide the cursor
$Alt   = "$e[?1049h"
$Main  = "$e[?1049l"

$ICH = "$e[{0}@" # Insert Character 	Insert <n> spaces at the current cursor position, shifting all existing text to the right. Text exiting the screen to the right is removed.
$DCH = "$e[{0}P" # Delete Character 	Delete <n> characters at the current cursor position, shifting in space characters from the right edge of the screen.
$ECH = "$e[{0}X" # Erase Character 	Erase <n> characters from the current cursor position by overwriting them with a space character.
$IL = "$e[{0}L" # Insert Line 	Inserts <n> lines into the buffer at the cursor position. The line the cursor is on, and lines below it, will be shifted downwards.
$DL = "$e[{0}M" # Delete Line 	Deletes <n> lines from the buffer, starting with the row the cursor is on.

$Freeze= "$e[{0};{1}r"
#EndRegion '.\Init\0.ps1' 58
#Region '.\Classes\Padding.ps1' 0
class Padding {
    [int]$Left = 0
    [int]$Right = 0
    [int]$Top = 0
    [int]$Bottom = 0

    [void]SetFromIntArray([int[]]$padding) {
        if ($padding.Count -ge 1) {
            $this.Left = $padding[0]
            $this.Right = $padding[0]
        }
        if ($padding.Count -ge 2) {
            $this.Right = $padding[1]
        }
        if ($padding.Count -ge 3) {
            $this.Top = $padding[2]
        }
        if ($padding.Count -ge 4) {
            $this.Bottom = $padding[3]
        }
    }

    [string]ToString() {
        return "{$($this.Left), $($this.Right), $($this.Top), $($this.Bottom)}"
    }

    Padding([int[]]$padding) {
        $this.SetFromIntArray($padding)
    }
    Padding([object[]]$padding) {
        $this.SetFromIntArray($padding)
    }
}
#EndRegion '.\Classes\Padding.ps1' 33
#Region '.\Private\TrimLines.ps1' 0
function TrimLines {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string[]]$Lines
    )
    begin {
        [string[]]$AllLines = @()
    }
    process {
        [string[]]$AllLines += $Lines -split "\r?\n"
    }
    end {
        $first = [Array]::FindIndex($AllLines, [Predicate[string]] {![string]::IsNullOrWhiteSpace($args[0])})
        $last = [Array]::FindLastIndex($AllLines, [Predicate[string]] {![string]::IsNullOrWhiteSpace($args[0])})
        $Index = 0
        if ($AllLines[$first+1] -match "^[- ]*$") {
            $AllLines[$first]
            $first += 2
        }
        foreach ($line in $AllLines[$first..$last]) {
            Add-Member -Input $line -MemberType NoteProperty -Name Index -Value $Index -PassThru
            $Index += 1
        }
    }
}
#EndRegion '.\Private\TrimLines.ps1' 26
#Region '.\Public\Select-Interactive.ps1' 0
function Select-Interactive {
    <#
        .SYNOPSIS
            Shows Format-Table output in an alternate buffer in the console to allow filtering & selection
        .DESCRIPTION
            Select-Interactive calls Format-Table and displays the output in an alternate buffer.
            In that buffer you can type to select (or filter, with the -Filterable switch) and use the up and down arrows to select items.
            To select multiple items, press space to toggle selection -- otherwise, just hit Enter to return the highlighted item.

            Supports scrolling (or filtering) when there are too many items for one screen.
    #>
    [CmdletBinding()]
    param (
        # A title to show above the items (defaults to no the table header)
        [string]$Title,

        # The items to select from
        [Parameter(ValueFromPipeline)]
        [PSObject[]]$InputObject,

        # An alternate color for the background of the alternate buffer
        [RgbColor]$BackgroundColor = $Host.PrivateData.WarningBackgroundColor,

        # The color of the border (defaults to the Warning foreground color)
        [RgbColor]$BorderColor = $Host.PrivateData.WarningForegroundColor,

        # If set, typing text _filters_ the list rather than moving the selection
        [switch]$Filterable
    )
    begin {
        [PSObject[]]$Collection = @()
    }
    process {
        [PSObject[]]$Collection += $InputObject
    }
    end {
        $DebugPreference = "SilentlyContinue"
        $null = $PSBoundParameters.Remove("InputObject")

        $Header, $Lines = $Lines = $Collection | Format-Table -GroupBy {} | Out-String -Stream | TrimLines
        if (!$Title) {
            $Title = $Header
        }

        $TitleHeight = if ($Title) {
            1 + ($Title -split "\r?\n").Count
        } else {
            0
        }

        $LineWidth = $Lines + @($Title) -replace $EscapeRegex | Measure-Object Length -Maximum | Select-Object -ExpandProperty Maximum
        $BorderWidth  = [Math]::Min($Host.UI.RawUI.WindowSize.Width, $LineWidth + 2)

        $LineHeight = $Lines.Count
        $BorderHeight = [Math]::Min($Host.UI.RawUI.WindowSize.Height, $LineHeight + 2 + $TitleHeight)

        # Use alternate screen buffer, and hide the text cursor
        Write-Host "$Alt$Hide" -NoNewline

        Show-Box -Width $BorderWidth -Height $BorderHeight -Title $Title -BackgroundColor $BackgroundColor -ForegroundColor $BorderColor
        # Make sure the top and bottom borders don't scroll
        Write-Host ("$Freeze" -f ($TitleHeight + 1), ($BorderHeight - 1)) -NoNewline

        # Write-Host "Press Up or Down keys and ENTER to select... $Up" -ForegroundColor $BorderColor -NoNewline

        $MaxHeight = $Host.UI.RawUI.WindowSize.Height - 2 - $TitleHeight
        $Width = [Math]::Min($LineWidth, $Host.UI.RawUI.WindowSize.Width - 2)

        $Left = 2
        $Top = 2 + $TitleHeight


        $Filter = [Text.StringBuilder]::new()
        $Filtered = $Lines

        $Select = @()
        $Active = $Max    = $Filtered.Count - 1
        $Height = [Math]::Min($Filtered.Count, $MaxHeight)
        $Offset = [Math]::Max(0, $Active - $Height + 1)

        $List = @{
            Top = $Top
            Left = $Left
            Width = $Width
            Height = $Height
            BackgroundColor = $BackgroundColor
        }

        Show-List @List -List $Filtered -Active $Active -SelectedItems $Select -Offset $Offset

        # # This doesn't seem necessary any more, but it was to make sure no keystrokes from before affect this
        # do {
        #     $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown")
        # } while ($Host.UI.RawUI.KeyAvailable)

        do {
            if (!$Host.UI.RawUI.KeyAvailable) {
                Start-Sleep -Milliseconds 10
                continue
            }
            $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            switch ($Key.VirtualKeyCode) {
                38 {# UP ARROW KEY
                    if (($Key.ControlKeyState -band "ShiftPressed") -eq "ShiftPressed") {
                        if ($Active -notin $Select) {
                            $Select += $Active
                        }
                    }
                    if ($Active -le 0) {
                        $Active = $Max
                        $Offset = $Filtered.Count - $Height
                    } else {
                        $Active = [Math]::Max(0, $Active - 1)
                        $Offset = [Math]::Min($Offset, $Active)
                    }
                    if (($Key.ControlKeyState -band "ShiftPressed") -eq "ShiftPressed") {
                        if ($Active -notin $Select) {
                            $Select += $Active
                        }
                    }
                    if ($PSBoundParameters.ContainsKey("Debug")) {
                        Write-Host -NoNewline (($SetXY -f ($Width - 45), 0) + ("{{UP}} Active: {0:d2} Offset: {1:d2} of {2:d3} ({3:d2})   " -f $Active, $Offset, $Max, $Filtered.Count) )
                    }
                }
                40 {# DOWN ARROW KEY
                    if (($Key.ControlKeyState -band "ShiftPressed") -eq "ShiftPressed") {
                        if ($Active -notin $Select) {
                            $Select += $Active
                        }
                    }
                    if ($Active -ge $Max) {
                        $Active = 0
                        $Offset = 0
                    } else {
                        $Active = [Math]::Min($Max, $Active + 1)
                        $Offset = [Math]::Max($Offset, $Active - $Height + 1)
                    }
                    if (($Key.ControlKeyState -band "ShiftPressed") -eq "ShiftPressed") {
                        if ($Active -notin $Select) {
                            $Select += $Active
                        }
                    }
                    if ($PSBoundParameters.ContainsKey("Debug")) {
                        Write-Host -NoNewline (($SetXY -f ($Width - 45), 0) + ("{{DN}} Active: {0:d2} Offset: {1:d2} of {2:d3}" -f $Active, $Offset, $Filtered.Count) )
                    }
                }
                # alpha numeric keys (and backspace)
                # Should allow punctuation, but doesn't yet
                {$_ -eq 8 -or $_ -ge 48 -and $_ -le 90} {
                    # backspace
                    if ($_ -eq 8) {
                        # Ctrl backspace
                        if ($Key.ControlKeyState -match "RightCtrlPressed|LeftCtrlPressed") {
                            while ($Filter.Length -and $Filter[-1] -notmatch "\s") {
                                $null = $Filter.Remove($Filter.Length - 1, 1)
                            }
                        }
                        if ($Filter.Length) {
                            $null = $Filter.Remove($Filter.Length - 1, 1)
                        }
                    } else {
                        $null = $Filter.Append($Key.Character)
                    }

                    if ($Filterable) {
                        if ($Filtered) {
                            $ActiveItem = $Filtered[$Active]
                        }

                        # Filter and redraw
                        if ($Filter.Length) {
                            $Filtered = $Lines | Where-Object { $_ -replace $EscapeRegex -match "\b$($Filter.ToString() -split " " -join '.*\b')" }
                        } else {
                            $Filtered = $Lines
                        }
                        $Active = if ($Filtered) {
                            [Math]::Max(0, ([Array]::IndexOf($Filtered, $ActiveItem)))
                        } else {
                            0
                        }
                        $Select = @()
                        $Offset = [Math]::Max(0, $Active - $List.Height + 1)
                        if ($PSBoundParameters.ContainsKey("Debug")) {
                            Write-Host -NoNewline (($SetXY -f ($Width - 45), 0) + ("{{Filter}} Active: {0:d2} Offset: {1:d2} of {2:d3}" -f $Active, $Offset, $Filtered.Count) )
                        }
                    } else {
                        # Scroll and highlight
                        $Selected = $Lines | Where-Object { $_  -replace $EscapeRegex -match "\b$($Filter.ToString() -split " " -join '.*\b')" }
                        $Active = $Selected | Select-Object -Expand Index -First 1
                        $Offset = [Math]::Max(0, $Active - $List.Height + 1)
                        if ($PSBoundParameters.ContainsKey("Debug")) {
                            Write-Host -NoNewline (($SetXY -f ($Width - 45), 0) + ("{{Filter}} Active: {0:d2} Offset: {1:d2} of {2:d3}" -f $Active, $Offset, $Filtered.Count) )
                        }
                    }

                    Write-Host (
                        ($SetXY -f 4, $BorderHeight) +
                        $Filter.ToString() +
                        $BorderColor.ToVtEscapeSequence() +
                        ($BoxChars.HorizontalDouble * ($Width - 4 - $Filter.Length)) +
                        $Fg:Clear
                    ) -NoNewline
                }
                32 { # Space: toggle selection
                    if ($Filter.Length -gt 0) {
                        $null = $Filter.Append($Key.Character)
                    }

                    if ($Active -in $Select) {
                        $Select = @($Select -ne $Active)
                    } else {
                        $Select += $Active
                    }
                }
                13 { # Enter: return results
                    Write-Host "$Main$Show" -NoNewline
                    if ($Select.Count -eq 0) {
                        $Select = @($Active)
                    }
                    $Collection[$Filtered[$Select].Index]
                    return
                }
                27 { # ESC: return nothing
                    Write-Host "$Main$Show" -NoNewline
                    $Select = @()
                    return
                }
            }
            $Max    = $Filtered.Count - 1
            $Height = [Math]::Min($Filtered.Count, $MaxHeight)
            Show-List @List -List $Filtered -SelectedItems $Select -Offset $Offset -Active $Active
        } while ($true)
    }
}
#EndRegion '.\Public\Select-Interactive.ps1' 234
#Region '.\Public\Show-Box.ps1' 0
function Show-Box {
    [CmdletBinding()]
    param (
        [string]$Title,

        [switch]$CenterTitle,

        [int]$Width = $($Host.UI.RawUI.WindowSize.Width),

        [int]$Height = $($Host.UI.RawUI.WindowSize.Height),

        [RgbColor]$BackgroundColor = $Host.PrivateData.WarningBackgroundColor,

        [RgbColor]$ForegroundColor = $Host.PrivateData.WarningForegroundColor
    )

    end {
        # Write-Verbose "Make a box of Width: $Width with background $BackgroundColor"
        $Height = [Math]::Min($Host.UI.RawUI.WindowSize.Height, $Height)
        $Width  = [Math]::Min($Host.UI.RawUI.WindowSize.Width, $Width)
        # Subtract the border cell
        $Width -= 2
        $Height -= 2

        $b = $BackgroundColor.ToVtEscapeSequence($true)
        $f = $ForegroundColor.ToVtEscapeSequence()

        # Top Bar
        Write-Host -NoNewline (
            $b + $f + $BoxChars.TopLeftDouble + ($BoxChars.HorizontalDouble * $Width) + $BoxChars.TopRightDouble
        )

        # Title Bar
        $TitleBar = @(
            if ($Title) {
                foreach ($l in $Title -split "\r?\n") {
                    $TitleLength = ($l -replace $EscapeRegex).Length
                    [int]$TitlePadding = if (!$CenterTitle) {
                        2
                    } else {
                        (($Width - $TitleLength) / 2) - 1
                    }
                    Write-Host -NoNewline (
                        "`n" + $b + $f + $BoxChars.VerticalDouble + (" " * $Width) + $BoxChars.VerticalDouble +
                        "$([char]27)[$($TitlePadding)G" + $Fg:Clear + $l
                    )
                }
                Write-Host -NoNewline (
                    "`n" + $b + $f + $BoxChars.VerticalDoubleRightDouble + ($BoxChars.HorizontalDouble * $Width) + $BoxChars.VerticalDoubleLeftDouble
                )
            }
        )
        $TitleBar
        # Main box
        for ($i = 0; $i -lt ($Height - $TitleHeight); $i++) {
            Write-Host -NoNewline ("`n" + $b + $f + $BoxChars.VerticalDouble + (" " * $Width) + $BoxChars.VerticalDouble)
        }

        # Bottom Bar (plus reset)
        Write-Host -NoNewline (
            "`n" + $b + $f + $BoxChars.BottomLeftDouble + ($BoxChars.HorizontalDouble * $Width) + $BoxChars.BottomRightDouble +
            $Fg:Clear +
            $Bg:Clear
        )
    }
}
#EndRegion '.\Public\Show-Box.ps1' 66
#Region '.\Public\Show-List.ps1' 0
function Show-List {
    [CmdletBinding()]
    param(
        [int]$Top = 1,
        [int]$Left = 1,
        [int]$Height = $Host.UI.RawUI.WindowSize.Height,
        [int]$Width = $Host.UI.RawUI.WindowSize.Width,
        [string[]]$List,
        [RgbColor]$BackgroundColor = "Black",
        [RgbColor]$HighlightColor  = "Gray",
        [RgbColor]$SelectionColor   = "DarkGray",
        [int[]]$SelectedItems,
        [int]$ActiveIndex = $($List.Count - 1),
        [int]$Offset = $([Math]::Max(0, $ActiveIndex - $Height))
    )
    $ActualHeight = [Math]::Min(($Host.UI.RawUI.WindowSize.Height - ($Top - 1)), $Height)
    $ActualHeight = [Math]::Min($ActualHeight, $List.Count)
    $Width  = [Math]::Min(($Host.UI.RawUI.WindowSize.Width - ($Left - 1)), $Width)

    # Fix the offset
    if ($ActiveIndex -lt $Offset) {
        $Offset = $ActiveIndex
    } elseif ($ActiveIndex -gt ($Offset + $ActualHeight)) {
        $Offset = $ActiveIndex - $ActualHeight
    }

    $Last = [Math]::Min($List.Count, $Offset + $ActualHeight)

    # Write out all the lines
    $Line   = $Top
    for ($i = $Offset; $i -lt $Last; $i++) {
        $Bg = if ($i -eq $ActiveIndex) {
            $HighlightColor.ToVtEscapeSequence($true)
        } elseif ($i -in $SelectedItems) {
            $SelectionColor.ToVtEscapeSequence($true)
        } else {
            $BackgroundColor.ToVtEscapeSequence($true)
        }
        $item = $List[$i].TrimEnd()
        $plainItem = $item -replace $EscapeRegex

        $item = $item + (" " * ($width - $plainItem.Length))
        if ($plainItem.Length -gt $Width) {
            $trimable = $plainItem.Substring($Width)
            $item = $item -replace ([regex]::Escape($trimable))
            $plainItem = $item -replace $EscapeRegex
        }

        Write-Host (($SetXY -f $Left, $Line++) + $Bg + $item + $Bg:Clear) -NoNewline
    }

    # if they filter, we're going to need to blank the rest of the lines
    $item = " " * $Width
    while ($Line -lt $Height + $Top) {
        Write-Host (($SetXY -f $Left, $Line++) + $BackgroundColor.ToVtEscapeSequence($true) + $item + $Bg:Clear) -NoNewline
    }
}
#EndRegion '.\Public\Show-List.ps1' 57
