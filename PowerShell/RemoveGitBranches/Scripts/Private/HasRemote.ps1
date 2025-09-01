function hasRemote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Branch
    )

    git show-ref --verify --quiet refs/remotes/origin/$Branch
    return $? -eq $true
}
