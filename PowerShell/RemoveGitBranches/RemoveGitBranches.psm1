Get-ChildItem -Path (Join-Path $PSScriptRoot 'Scripts/Public') -Filter *.ps1 |
ForEach-Object {.$_.FullName }
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Scripts/Private') -Filter *.ps1 |
ForEach-Object {.$_.FullName }

Set-Alias -Name rgb -Value Remove-GitBranches

Export-ModuleMember -Function 'Remove-GitBranches' -Alias 'rgb'
