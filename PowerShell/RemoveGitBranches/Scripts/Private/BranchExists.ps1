function branchExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Branch
    )

    Invoke-GitCultureInvariant -args @('show-ref', '--verify', '--quiet', "refs/heads/$Branch")
    return $LASTEXITCODE -eq 0
}
