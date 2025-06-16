# Fuzzy Text Matching Algorithms

# Keep the original Levenshtein functions for backward compatibility
function global:Get-LevenshteinDistance {
    param(
        [string]$String1,
        [string]$String2,
        [switch]$CaseSensitive
    )
    
    if (-not $CaseSensitive) {
        $String1 = $String1.ToLower()
        $String2 = $String2.ToLower()
    }
    
    $len1 = $String1.Length
    $len2 = $String2.Length
    
    # Use hashtable approach to avoid PowerShell multidimensional array issues
    $matrix = @{}
    
    for ($i = 0; $i -le $len1; $i++) { $matrix["$i,0"] = $i }
    for ($j = 0; $j -le $len2; $j++) { $matrix["0,$j"] = $j }
    
    for ($i = 1; $i -le $len1; $i++) {
        for ($j = 1; $j -le $len2; $j++) {
            $cost = if ($String1[$i-1] -eq $String2[$j-1]) { 0 } else { 1 }
            
            $matrix["$i,$j"] = [Math]::Min(
                [Math]::Min( $matrix["$($i-1),$j"] + 1, $matrix["$i,$($j-1)"] + 1 ),
                $matrix["$($i-1),$($j-1)"] + $cost
            )
        }
    }
    return $matrix["$len1,$len2"]
}

function global:Get-FuzzySimilarity {
    param(
        [string]$String1,
        [string]$String2,
        [switch]$CaseSensitive
    )
    
    $distance = Get-LevenshteinDistance -String1 $String1 -String2 $String2 -CaseSensitive:$CaseSensitive
    $maxLen = [Math]::Max($String1.Length, $String2.Length)
    
    if ($maxLen -eq 0) { return 100 }
    
    $similarity = (1 - ($distance / $maxLen)) * 100
    return [Math]::Round($similarity, 2)
}

# New fuzzy match function optimized for command palettes
function global:Get-FuzzyMatch {
    param(
        [string]$SearchTerm,
        [string]$Target,
        [switch]$CaseSensitive
    )
    
    if ([string]::IsNullOrWhiteSpace($SearchTerm)) { return 100 }
    if ([string]::IsNullOrWhiteSpace($Target)) { return 0 }
    
    if (-not $CaseSensitive) {
        $SearchTerm = $SearchTerm.ToLower()
        $Target = $Target.ToLower()
    }
    
    # Replace underscores with spaces for more flexible matching
    # This allows "ca_" to match "Calendar View"
    $SearchTerm = $SearchTerm.Replace('_', ' ')
    
    $score = 0
    $searchIndex = 0
    $targetIndex = 0
    $consecutiveMatches = 0
    $matchPositions = @()
    
    # First, check if all characters in search term exist in order
    while ($searchIndex -lt $SearchTerm.Length -and $targetIndex -lt $Target.Length) {
        if ($SearchTerm[$searchIndex] -eq $Target[$targetIndex]) {
            $matchPositions += $targetIndex
            $searchIndex++
            $consecutiveMatches++
            
            # Bonus for consecutive matches
            if ($matchPositions.Count -gt 1 -and $matchPositions[-1] -eq $matchPositions[-2] + 1) {
                $score += 5 * $consecutiveMatches
            } else {
                $consecutiveMatches = 1
            }
            
            # Bonus for matching at start of string
            if ($targetIndex -eq 0) {
                $score += 15
            }
            
            # Bonus for matching after word boundary
            if ($targetIndex -gt 0 -and $Target[$targetIndex - 1] -match '\W') {
                $score += 10
            }
        }
        $targetIndex++
    }
    
    # If not all characters were found, return 0
    if ($searchIndex -lt $SearchTerm.Length) {
        return 0
    }
    
    # Base score for finding all characters
    $score += 50
    
    # Bonus for exact substring match
    if ($Target.Contains($SearchTerm)) {
        $score += 30
        
        # Extra bonus if it's at the beginning
        if ($Target.StartsWith($SearchTerm)) {
            $score += 20
        }
    }
    
    # Penalty for length difference (prefer shorter, more relevant matches)
    $lengthPenalty = ($Target.Length - $SearchTerm.Length) * 0.5
    $score -= $lengthPenalty
    
    # Ensure score doesn't go below 0
    return [Math]::Max(0, [Math]::Round($score, 2))
}

# Wrapper function to maintain compatibility with existing code
function global:Get-CommandPaletteFuzzyScore {
    param(
        [string]$SearchTerm,
        [string]$Target,
        [switch]$CaseSensitive
    )
    
    # For command palette, use the new fuzzy match algorithm
    return Get-FuzzyMatch -SearchTerm $SearchTerm -Target $Target -CaseSensitive:$CaseSensitive
}
