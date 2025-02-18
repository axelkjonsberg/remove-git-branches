function Remove-GitBranches {
    if ((git rev-parse --is-inside-work-tree) -ne $true) {
        Write-Host "Not inside a Git repository" -ForegroundColor Red
        return
    }

    # Ensure UTF-8 during execution of the command
    $originalEncodingOfUser = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8

    try {
        Invoke-GitCultureInvariant -args @('fetch','-p')

        $currentBranch = (git symbolic-ref --short -q HEAD).Trim()

        $masterBranch =
        if (branchExists 'master') { 'master' }
        elseif (branchExists 'main') { 'main' }

        $masterBranchExists = $null -ne $masterBranch

        # Check if current branch has a remote and if user wants to delete the current branch
        if (-not (hasRemote $currentBranch) -and $masterBranchExists -and $currentBranch -ne $masterBranch) {
            $deleteCurrent = (Read-Host "Current local branch '$currentBranch' has no remote; delete this and switch to '$masterBranch'? (Y/n)") -ne 'n'
        }

        $shouldSwitchBranch = $deleteCurrent -and $currentBranch -ne $masterBranch

        if ($shouldSwitchBranch -and -not $masterBranchExists) {
            Write-Host "Neither 'main' nor 'master' branches exist. Cannot switch branches after deleting current." -ForegroundColor Red
            return
        }

        $localBranches = (Invoke-GitCultureInvariant -args @('branch')).ForEach({ $_.Trim().Replace('* ','') })
        $remoteBranches = (Invoke-GitCultureInvariant -args @('branch','-r')).ForEach({ $_.Trim().Replace('origin/','') })

        $branchesToDelete = $localBranches | Where-Object { $_ -notin $remoteBranches -and $_ -ne 'master' -and $_ -ne 'main' -and (($_ -ne $currentBranch) -or $deleteCurrent) }

        if (-not $branchesToDelete) {
            Write-Host "No local branches to delete" -ForegroundColor Cyan
            return
        }

        Write-Host "The following local Git branches will be deleted:" -ForegroundColor Yellow
        $branchesToDelete | ForEach-Object { Write-Host "  - $_" -ForegroundColor Magenta }

        if ((Read-Host "Are you sure you want to delete these local branches? (Y/n)") -eq 'n') {
            Write-Host "No local branches were deleted" -ForegroundColor Cyan
            return
        }

        if ($shouldSwitchBranch) {
            Invoke-GitCultureInvariant -args @('checkout',$masterBranch)
        }

        $branchesToDelete | ForEach-Object {
            Invoke-GitCultureInvariant -args @('branch','-D',$_)
        }

        Write-Host "The local branches were deleted successfully" -ForegroundColor Green
    }
    finally {
        # Restore the user's original encoding
        [Console]::OutputEncoding = $originalEncodingOfUser
    }
}
