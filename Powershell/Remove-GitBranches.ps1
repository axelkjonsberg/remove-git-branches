# TODO: Check if branch has incomming updates, if so, don't delete
# TODO: Fix DeleteCurrent. Should check the * prefixes 

function Remove-GitBranches {
    param (
        [Parameter(Mandatory = $false)]
        [bool]$DeleteCurrent = $false
    )

    # Check if not inside a Git repository
    if ((git rev-parse --is-inside-work-tree) -ne $true) {
        Write-Host "Not inside a Git repository" -ForegroundColor Red
        return
    }

    # Fetch and prune
    git fetch -p

    # Get current branch
    $currentBranch = git symbolic-ref --short -q HEAD

    # If the switch flag is set, stash changes and switch to main or master
    if ($DeleteCurrent -and $currentBranch -ne 'main' -and $currentBranch -ne 'master') {
        git stash --include-untracked
        if (git show-ref --verify --quiet refs/heads/main) {
            git checkout main
        }
        # If main does not exist, but master does, switch to it
        if (!(git show-ref --verify --quiet refs/heads/main) -and (git show-ref --verify --quiet refs/heads/master)) {
            git checkout master
        }
        if (!(git show-ref --verify --quiet refs/heads/main) -and !(git show-ref --verify --quiet refs/heads/master)) {
            Write-Host "Neither 'main' nor 'master' branches exist. Cannot switch branches" -ForegroundColor Red
            return
        }
    }

    # Get a list of branches to delete
    $branchesToDelete = git branch | ForEach-Object {
        $branchName = $_.Trim()

        # Remove the asterisk prefix if present
        if ($branchName.StartsWith('* ')) {
            $branchName = $branchName.Substring(2)
        }

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

    if ($confirmation -eq 'y') {
        $branchesToDelete | ForEach-Object {
            git branch -D $_
        }
        Write-Host "The branches were deleted successfully" -ForegroundColor Green
        return
    }

    Write-Host "No branches were deleted" -ForegroundColor Cyan
}

New-Alias -Name rgb -Value Remove-GitBranches

function Remove-GitBranchesWithSwitch {
    Remove-GitBranches -DeleteCurrent $true
}
New-Alias -Name rgbdc -Value Remove-GitBranchesWithSwitch