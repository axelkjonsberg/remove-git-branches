function hasRemote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Branch
    )

    $remoteBranches = Invoke-GitCultureInvariant -args @('for-each-ref', '--format=%(refname:lstrip=3)', 'refs/remotes')
    return ($remoteBranches -contains $Branch)
}
