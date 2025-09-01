function Remove-GitBranches {
    param(
        [switch]$Help
    )

    if ($Help) {
        Write-Host "`nRemove-GitBranches:" -ForegroundColor Cyan
        Write-Host "A command for safely deleting local Git branches which have been deleted from remote repository." -ForegroundColor White
        Write-Host "`nUSAGE:" -ForegroundColor Yellow
        Write-Host "  Remove-GitBranches" -ForegroundColor White
        Write-Host "`nOPTIONS:" -ForegroundColor Yellow
        Write-Host "  -Help       Displays this help message." -ForegroundColor White
        Write-Host "`nDESCRIPTION:" -ForegroundColor Yellow
        Write-Host "  This command deletes local Git branches that no longer have a remote counterpart (except for the main and master branches)."
        Write-Host "`nBEHAVIOR:" -ForegroundColor Yellow
        Write-Host "  - Prompts the user before deleting branches without remotes."
        Write-Host "  - Automatically switches to 'main' or 'master' branch after execution if necessary." -ForegroundColor White
        return
    }

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

        $branchesToDelete = $localBranches | Where-Object {
            $branchHasNoRemote = $_ -notin $remoteBranches
            $branchIsNotMaster = $_ -ne 'master' -and $_ -ne 'main'
            $branchShouldBeDeletedIfCheckedOut = ($_ -ne $currentBranch) -or $deleteCurrent

            $branchHasNoRemote -and $branchIsNotMaster -and $branchShouldBeDeletedIfCheckedOut
        }

        if (-not $branchesToDelete) {
            Write-Host "No local branches to delete" -ForegroundColor Cyan
            return
        }

        Write-Host "The following local Git branches will be deleted:" -ForegroundColor Yellow
        $branchesToDelete | ForEach-Object { Write-Host "  - $_" -ForegroundColor Magenta }

        if ((Read-Host "Delete these local branches? (Y/n)") -eq 'n') {
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
