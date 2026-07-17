function Remove-GitBranches {
    [CmdletBinding()]
    param(
        [switch]$Help,
        [switch]$DeleteCurrent,
        [switch]$Yes
    )

    if ($Help) {
        Write-Host "`nRemove-GitBranches:" -ForegroundColor Cyan
        Write-Host "Safely delete local branches that no longer exist on the remote." -ForegroundColor White
        Write-Host "`nUSAGE:" -ForegroundColor Yellow
        Write-Host "  Remove-GitBranches [-DeleteCurrent] [-Yes] [-Help]" -ForegroundColor White
        Write-Host "`nOPTIONS:" -ForegroundColor Yellow
        Write-Host "  -DeleteCurrent  Also delete the current branch (if it has no remote)." -ForegroundColor White
        Write-Host "  -Yes            Skip confirmation prompts." -ForegroundColor White
        Write-Host "  -Help           Show this help." -ForegroundColor White
        return
    }

    Invoke-GitCultureInvariant -args @('rev-parse', '--is-inside-work-tree') *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Not inside a Git repository" -ForegroundColor Red
        return
    }

    # Ensure UTF-8 during execution of the command
    $originalEncodingOfUser = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8

    try {
        Invoke-GitCultureInvariant -args @('fetch','-p')
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to fetch from the remote; aborting without deleting anything." -ForegroundColor Red
            return
        }

        $currentBranch = "$(Invoke-GitCultureInvariant -args @('symbolic-ref','--short','-q','HEAD'))".Trim()

        function Get-DefaultBranch {
            if (branchExists 'master') { return 'master' }
            if (branchExists 'main') { return 'main' }
            $remoteHead = Invoke-GitCultureInvariant -args @('symbolic-ref','-q','--short','refs/remotes/origin/HEAD') |
            ForEach-Object { $_.Trim() }
            if ($LASTEXITCODE -eq 0 -and $remoteHead) {
                return ($remoteHead -replace '^origin/','')
            }
            return $null
        }

        $defaultBranch = Get-DefaultBranch

        if ($currentBranch -and -not (hasRemote $currentBranch) -and $defaultBranch -and $currentBranch -ne $defaultBranch -and -not $DeleteCurrent) {
            if ($Yes) {
                $DeleteCurrent = $true
            } else {
                $resp = Read-Host "Current local branch '$currentBranch' has no remote; delete this and switch to '$defaultBranch'? (Y/n)"
                $DeleteCurrent = (-not $resp.ToLower().StartsWith('n'))
            }
        }

        if ($DeleteCurrent -and -not $defaultBranch) {
            Write-Host "There exists no default branch ('main'/'master' or origin/HEAD) to switch to after deleting current branch." -ForegroundColor Red
            return
        }

        # Collect refs without parsing `git branch` output
        $localBranches = Invoke-GitCultureInvariant -args @('for-each-ref','--format=%(refname:short)','refs/heads')
        $remoteBranches = Invoke-GitCultureInvariant -args @('for-each-ref','--format=%(refname:lstrip=3)','refs/remotes') |
        Where-Object { $_ -ne 'HEAD' }

        $remoteSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $remoteBranches | ForEach-Object { [void]$remoteSet.Add($_) }

        $branchesToDelete = $localBranches | Where-Object {
            ($_ -ne 'master' -and $_ -ne 'main') -and
            ($_ -ne $defaultBranch) -and
            ($_ -ne $currentBranch -or $DeleteCurrent) -and
            (-not $remoteSet.Contains($_))
        }

        if (-not $branchesToDelete) {
            Write-Host "No local branches to delete" -ForegroundColor Cyan
            return
        }

        Write-Host "The following local Git branches will be deleted:" -ForegroundColor Yellow
        $branchesToDelete | ForEach-Object { Write-Host "  - $_" -ForegroundColor Magenta }

        if (-not $Yes) {
            $resp = Read-Host "Delete these local branches? (Y/n)"
            if ($resp.ToLower().StartsWith('n')) {
                Write-Host "No local branches were deleted" -ForegroundColor Cyan
                return
            }
        }

        if ($DeleteCurrent -and $currentBranch -ne $defaultBranch) {
            Invoke-GitCultureInvariant -args @('switch',$defaultBranch) *>$null
            if ($LASTEXITCODE -ne 0) {
                Invoke-GitCultureInvariant -args @('checkout',$defaultBranch) *>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Failed to switch to '$defaultBranch'; no branches were deleted." -ForegroundColor Red
                    return
                }
            }
        }

        $deleteFailed = $false
        foreach ($branch in $branchesToDelete) {
            Invoke-GitCultureInvariant -args @('branch','-D',$branch)
            if ($LASTEXITCODE -ne 0) { $deleteFailed = $true }
        }

        if ($deleteFailed) {
            Write-Host "Some local branches could not be deleted" -ForegroundColor Red
            return
        }

        Write-Host "The local branches were deleted successfully" -ForegroundColor Green
    }
    finally {
        [Console]::OutputEncoding = $originalEncodingOfUser
    }
}
