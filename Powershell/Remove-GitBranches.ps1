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

    if ((git rev-parse --is-inside-work-tree) -ne $true) {
        Write-Host "Not inside a Git repository" -ForegroundColor Red
        return
    }

    git fetch -p

    $currentBranch = (git symbolic-ref --short -q HEAD).Trim()

    $masterBranch =
    if (branchExists 'master') { 'master' }
    elseif (branchExists 'main') { 'main' }

    $masterBranchExists = $null -ne $masterBranch

    if (-not $DeleteCurrent -and $masterBranchExists -and $currentBranch -ne $masterBranch) {
        $DeleteCurrent = (Read-Host "Also delete current branch '$currentBranch' and switch to '$masterBranch'? (Y/n)") -ne 'n'
    }

    $shouldSwitchBranch = $DeleteCurrent -and $currentBranch -ne $masterBranch

    if ($shouldSwitchBranch -and -not $masterBranchExists) {
        Write-Host "Neither 'main' nor 'master' branches exist. Cannot switch branches after deleting current." -ForegroundColor Red
        return
    }

    $localBranches = (git branch).ForEach({ $_.Trim().Replace('* ', '') })
    $remoteBranches = (git branch -r).ForEach({ $_.Trim().Replace('origin/', '') })

    $branchesToDelete = $localBranches | Where-Object { $_ -notin $remoteBranches -and $_ -ne 'master' -and $_ -ne 'main' -and (($_ -ne $currentBranch) -or $DeleteCurrent) }

    if (-not $branchesToDelete) {
        Write-Host "No branches to delete" -ForegroundColor Cyan
        return
    }

    Write-Host "The following local Git branches will be deleted:" -ForegroundColor Yellow
    $branchesToDelete | ForEach-Object { Write-Host "  - $_" -ForegroundColor Magenta }
    
    if ((Read-Host "Are you sure you want to delete these branches? (Y/n)") -eq 'n') {
        Write-Host "No branches were deleted" -ForegroundColor Cyan
        return
    }
    
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