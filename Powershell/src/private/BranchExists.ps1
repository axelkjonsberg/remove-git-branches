function branchExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Branch
    )

    git show-ref --verify --quiet refs/heads/$Branch
    return $? -eq $true
}
