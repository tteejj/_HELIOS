# Simple Multiline Text Input for PowerShell Console
# NOTE: Behavior can vary between terminals (e.g., Windows Terminal vs. VSCode Integrated Console).
# Best used in a standard Windows Terminal or pwsh.exe window.

function global:Read-MultilineText {
    param(
        [string[]]$InitialContent = @("")
    )

    $lines = if ($InitialContent) { @($InitialContent) } else { @("") }
    $cursorLine = 0
    $cursorCol = 0
    $startTop = [Console]::CursorTop
    
    [Console]::CursorVisible = $true
    
    # Simple clear for the editing area. More advanced would track lines and only clear those.
    function Clear-EditArea {
        [Console]::SetCursorPosition(0, $startTop)
        for ($i = 0; $i -lt ([Console]::WindowHeight - $startTop); $i++) {
            Write-Host (" " * ([Console]::WindowWidth - 1))
        }
    }

    while ($true) {
        # Redraw all lines from the start position
        [Console]::SetCursorPosition(0, $startTop)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            Write-Host $lines[$i].PadRight([Console]::WindowWidth - 1)
        }
        
        # Position cursor at the correct editing spot
        [Console]::SetCursorPosition($cursorCol, $startTop + $cursorLine)
        
        # Read the next key press
        $key = [Console]::ReadKey($true)
        
        switch ($key.Key) {
            "Enter" {
                if (($key.Modifiers -band [System.ConsoleModifiers]::Control)) { # Ctrl+Enter to finish
                    Clear-EditArea
                    [Console]::SetCursorPosition(0, $startTop)
                    return $lines -join "`n"
                }
                $before = $lines[$cursorLine].Substring(0, $cursorCol)
                $after = $lines[$cursorLine].Substring($cursorCol)
                $lines[$cursorLine] = $before
                $lines = $lines[0..$cursorLine] + @($after) + $lines[($cursorLine+1)..($lines.Count-1)]
                $cursorLine++
                $cursorCol = 0
            }
            "Backspace" {
                if ($cursorCol -gt 0) {
                    $lines[$cursorLine] = $lines[$cursorLine].Remove($cursorCol - 1, 1)
                    $cursorCol--
                } elseif ($cursorLine -gt 0) {
                    $cursorCol = $lines[$cursorLine - 1].Length
                    $lines[$cursorLine - 1] += $lines[$cursorLine]
                    $lines = $lines[0..($cursorLine-1)] + $lines[($cursorLine+1)..($lines.Count-1)]
                    $cursorLine--
                    Clear-EditArea
                }
            }
            "Delete" {
                if ($cursorCol -lt $lines[$cursorLine].Length) {
                    $lines[$cursorLine] = $lines[$cursorLine].Remove($cursorCol, 1)
                } elseif ($cursorLine -lt ($lines.Count - 1)) {
                    $lines[$cursorLine] += $lines[$cursorLine + 1]
                    $lines = $lines[0..$cursorLine] + $lines[($cursorLine+2)..($lines.Count-1)]
                    Clear-EditArea
                }
            }
            "LeftArrow" { if ($cursorCol -gt 0) { $cursorCol-- } elseif ($cursorLine -gt 0) { $cursorLine--; $cursorCol = $lines[$cursorLine].Length } }
            "RightArrow" { if ($cursorCol -lt $lines[$cursorLine].Length) { $cursorCol++ } elseif ($cursorLine -lt ($lines.Count - 1)) { $cursorLine++; $cursorCol = 0 } }
            "UpArrow" { if ($cursorLine -gt 0) { $cursorLine--; $cursorCol = [Math]::Min($cursorCol, $lines[$cursorLine].Length) } }
            "DownArrow" { if ($cursorLine -lt ($lines.Count - 1)) { $cursorLine++; $cursorCol = [Math]::Min($cursorCol, $lines[$cursorLine].Length) } }
            "Escape" {
                Clear-EditArea
                [Console]::SetCursorPosition(0, $startTop)
                return $lines -join "`n"
            }
            default {
                if (-not [char]::IsControl($key.KeyChar)) {
                    $lines[$cursorLine] = $lines[$cursorLine].Insert($cursorCol, $key.KeyChar)
                    $cursorCol++
                }
            }
        }
    }
}
