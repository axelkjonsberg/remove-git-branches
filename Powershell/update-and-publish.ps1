param(
    [string]$ManifestPath,
    [string]$NuGetApiKey,
    [string]$LatestTag
)

$Pattern = '(?<=ModuleVersion = '')[\d\.]+(?='')'
$Content = Get-Content $ManifestPath -Raw
$UpdatedContent = $Content -replace $Pattern,$LatestTag
$UpdatedContent | Set-Content $ManifestPath

git config --local user.email "action@github.com"
git config --local user.name "GitHub Actions"
git add $ManifestPath
git commit -m "Update module manifest version to $LatestTag"
git push --set-upstream origin "$(git branch --show-current)"

Publish-Module -Path '.' -NuGetApiKey $NuGetApiKey
