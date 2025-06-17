# Test data initialization script
# Run this before running main-helios.ps1 to ensure data exists

# Initialize global data structure if it doesn't exist
if (-not $global:Data) {
    $global:Data = @{
        tasks = @(
            @{
                id = [Guid]::NewGuid().ToString()
                title = "Complete project documentation"
                description = "Write comprehensive docs for the new system"
                priority = "High"
                category = "Work"
                due_date = (Get-Date).AddDays(2).ToString("yyyy-MM-dd")
                completed = $false
                created = Get-Date
            },
            @{
                id = [Guid]::NewGuid().ToString()
                title = "Review pull requests"
                description = "Check pending PRs on GitHub"
                priority = "Medium"
                category = "Work"
                due_date = (Get-Date).ToString("yyyy-MM-dd")
                completed = $false
                created = (Get-Date).AddHours(-2)
            },
            @{
                id = [Guid]::NewGuid().ToString()
                title = "Team meeting preparation"
                description = "Prepare slides for weekly sync"
                priority = "Critical"
                category = "Work"
                due_date = (Get-Date).ToString("yyyy-MM-dd")
                completed = $false
                created = (Get-Date).AddHours(-5)
            }
        )
        
        projects = @{
            "proj1" = @{ name = "Helios Refactor"; active = $true }
            "proj2" = @{ name = "Client Portal"; active = $true }
        }
        
        time_entries = @()
        active_timers = @{}
    }
}

Write-Host "Test data initialized successfully!" -ForegroundColor Green
Write-Host "Tasks: $($global:Data.tasks.Count)" -ForegroundColor Cyan
Write-Host "Projects: $($global:Data.projects.Count)" -ForegroundColor Cyan

# Optionally save the data
if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
    Save-UnifiedData
    Write-Host "Data saved to disk" -ForegroundColor Green
}
