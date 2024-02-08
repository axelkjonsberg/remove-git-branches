# Dot-source public functions
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    .$_.FullName
}

# Dot-source private functions
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    .$_.FullName
}

Set-Alias -Name rgb -Value Remove-GitBranches
Export-ModuleMember -Function 'Remove-GitBranches' -Alias 'rgb'
