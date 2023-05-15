function Remove-GitBranches {
    param (
        [Parameter(Mandatory = $false)]
        [bool]$DeleteCurrent = $false
    )

    ### Local helper functions
    function branchExists($branch) {
        git show-ref --verify --quiet refs/heads/$branch
        return $? -eq $true
    }
    ###

    # Check if not inside a Git repository
    if ((git rev-parse --is-inside-work-tree) -ne $true) {
        Write-Host "Not inside a Git repository" -ForegroundColor Red
        return
    }

    # Fetch and prune
    git fetch -p

    # Get current branch
    $currentBranch = git symbolic-ref --short -q HEAD

    $masterBranch = ''
    if ($DeleteCurrent) {
        if (branchExists 'master') {
            $masterBranch = 'master'
        }

        if (branchExists 'main') {
            $masterBranch = 'main'
        }

        if ($masterBranch -eq '') {
            Write-Host "Neither 'main' nor 'master' branches exist. Cannot switch branches after deleting current." -ForegroundColor Red
            return
        }
    }

    $shouldSwitchBranch = $DeleteCurrent -and $currentBranch -ne $masterBranch

    # Get a list of local branches
    $localBranches = git branch | ForEach-Object {
        # Remove the asterisk prefix if present and trim white spaces
        $branchName = $_.Trim().Replace('* ', '')
        return $branchName
    }

    # Get a list of remote branches
    $remoteBranches = git branch -r | ForEach-Object {
        # Remove the "origin/" prefix and trim white spaces
        $branchName = $_.Trim().Replace('origin/', '')
        return $branchName
    }

    # Get a list of branches to delete
    $branchesToDelete = $localBranches | Where-Object { $branchName = $_; -not ($remoteBranches -contains $branchName) } | ForEach-Object {
        # Skip master and main branches
        if ($branchName -eq 'master' -or $branchName -eq 'main') {
            return
        }
        
        # Skip current branch if DeleteCurrent flag is not true
        if ($branchName -eq $currentBranch -and !$DeleteCurrent) {
            return
        }

        # Add branch to list
        return $branchName
    }

    # If there are no branches to delete, return
    if ($branchesToDelete.Count -eq 0) {
        Write-Host "No branches to delete" -ForegroundColor Cyan
        return
    }

    # Display branches to delete and prompt for confirmation
    Write-Host "The following local Git branches will be deleted:" -ForegroundColor Yellow
    $branchesToDelete | ForEach-Object { Write-Host "  - $_" -ForegroundColor Magenta }
    $confirmation = Read-Host "Are you sure you want to delete these branches? (y/N)"
    
    if ($confirmation -ne 'y') {
        Write-Host "No branches were deleted" -ForegroundColor Cyan
        return
    }
    
    # If the DeleteCurrent flag is true, and current branch is equal to master branch, stash changes, switch to main or master, and pop and apply stash
    if ($shouldSwitchBranch) {
        git checkout $masterBranch
    }

    $branchesToDelete | ForEach-Object {
        git branch -D $_
    }
    Write-Host "The branches were deleted successfully" -ForegroundColor Green
}

New-Alias -Name rgb -Value Remove-GitBranches

function Remove-GitBranchesIncludingCurrent {
    Remove-GitBranches -DeleteCurrent $true
}
New-Alias -Name rgbdc -Value Remove-GitBranchesIncludingCurrent