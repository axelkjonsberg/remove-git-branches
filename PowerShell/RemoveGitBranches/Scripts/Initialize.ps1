$InitializationErrors = @()

if (-not (Test-Path $PSScriptRoot)) {
    $InitializationErrors += "Unable to determine script root. Initialization aborted."
}

# Check if Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $InitializationErrors += "Git is not installed or not in the system PATH. Please install Git to use this module."
}

# Check PowerShell version
if ($PSVersionTable.PSVersion -lt [Version]::new(5, 1)) {
    $InitializationErrors += "PowerShell version 5.1 or later is required. Please update your PowerShell version."
}

# Display errors if initialization failed
if ($InitializationErrors.Count -gt 0) {
    Write-Host "`nInitialization failed for 'Remove-GitBranches'. The module will not be fully loaded." -ForegroundColor Red
    Write-Host "Please resolve the following issues:" -ForegroundColor Yellow
    $InitializationErrors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    return
}
