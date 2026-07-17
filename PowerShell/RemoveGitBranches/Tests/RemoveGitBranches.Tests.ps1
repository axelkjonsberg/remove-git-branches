BeforeAll {
    $ModuleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'RemoveGitBranches.psd1'
    Import-Module $ModuleManifest -Force

    function New-TestRepo {
        $suffix = [guid]::NewGuid().ToString('N')
        $remoteDir = Join-Path $TestDrive "$suffix-origin.git"
        $seedDir = Join-Path $TestDrive "$suffix-seed"
        $localDir = Join-Path $TestDrive "$suffix-work"

        git init -q --bare -b main $remoteDir | Out-Null

        git init -q -b main $seedDir | Out-Null
        Push-Location $seedDir
        git config user.email test@example.com
        git config user.name 'Test User'
        git config commit.gpgsign false
        git commit -q --allow-empty -m init
        git remote add origin $remoteDir
        git push -q origin main
        Pop-Location
        Remove-Item -Recurse -Force $seedDir

        git clone -q $remoteDir $localDir 2>$null | Out-Null
        Push-Location $localDir
        git config user.email test@example.com
        git config user.name 'Test User'
        git config commit.gpgsign false
        Pop-Location

        return $localDir
    }

    function New-LocalBranch([string]$Name) {
        git branch -q $Name main
    }

    function New-TrackedBranch([string]$Name) {
        git branch -q $Name main
        git push -q origin $Name 2>$null
    }
}

Describe 'Remove-GitBranches' {
    BeforeEach {
        $repo = New-TestRepo
        Push-Location $repo
    }

    AfterEach {
        Pop-Location
    }

    It '-Help prints usage without requiring a git repository' {
        Pop-Location
        Push-Location $TestDrive
        $output = Remove-GitBranches -Help *>&1 | Out-String
        $output | Should -Match 'USAGE'
    }

    It 'fails outside a git repository' {
        Pop-Location
        $outside = Join-Path $TestDrive 'not-a-repo'
        New-Item -ItemType Directory -Path $outside -Force | Out-Null
        Push-Location $outside
        $output = Remove-GitBranches -Yes *>&1 | Out-String
        $output | Should -Match 'Not inside a Git repository'
    }

    It 'reports nothing to delete when only the default branch exists' {
        $output = Remove-GitBranches -Yes *>&1 | Out-String
        $output | Should -Match 'No local branches to delete'
    }

    It 'deletes a local branch that never had a remote' {
        New-LocalBranch -Name 'orphan/no-remote'
        Remove-GitBranches -Yes *>&1 | Out-Null
        git branch --list 'orphan/no-remote' | Should -BeNullOrEmpty
    }

    It 'fetches and prunes, then deletes a branch whose remote counterpart was removed' {
        New-TrackedBranch -Name 'feature/merged'
        Remove-GitBranches -Yes *>&1 | Out-Null
        git branch --list 'feature/merged' | Should -Not -BeNullOrEmpty

        git push -q origin --delete feature/merged 2>$null

        Remove-GitBranches -Yes *>&1 | Out-Null
        git branch --list 'feature/merged' | Should -BeNullOrEmpty
    }

    It 'never deletes a local branch named master, even without a remote' {
        git branch -q master main
        Remove-GitBranches -Yes *>&1 | Out-Null
        git branch --list master | Should -Not -BeNullOrEmpty
    }

    It 'does not delete the current branch by default when declined' {
        git checkout -q -b feature/current main
        Mock -ModuleName RemoveGitBranches Read-Host { 'n' }
        $output = Remove-GitBranches *>&1 | Out-String
        $output | Should -Match 'No local branches to delete'
        git branch --list feature/current | Should -Not -BeNullOrEmpty
    }

    It 'confirms current-branch deletion, switches to default branch, then deletes it' {
        git checkout -q -b feature/current main
        Mock -ModuleName RemoveGitBranches Read-Host { 'y' }
        $output = Remove-GitBranches *>&1 | Out-String
        $output | Should -Match 'deleted successfully'
        (git rev-parse --abbrev-ref HEAD) | Should -Be 'main'
        git branch --list feature/current | Should -BeNullOrEmpty
    }

    It '-Yes deletes the current branch without prompting' {
        git checkout -q -b feature/current main
        Mock -ModuleName RemoveGitBranches Read-Host { throw 'Read-Host should not be called when -Yes is set' }
        Remove-GitBranches -Yes *>&1 | Out-Null
        (git rev-parse --abbrev-ref HEAD) | Should -Be 'main'
        git branch --list feature/current | Should -BeNullOrEmpty
        Should -Invoke -ModuleName RemoveGitBranches Read-Host -Times 0
    }

    It '-DeleteCurrent skips the first prompt but still confirms deletion' {
        git checkout -q -b feature/current main
        Mock -ModuleName RemoveGitBranches Read-Host { 'y' }
        Remove-GitBranches -DeleteCurrent *>&1 | Out-Null
        git branch --list feature/current | Should -BeNullOrEmpty
    }

    It 'does not claim success and leaves current branch untouched when switch and checkout fallback both fail' {
        Set-Content -Path (Join-Path $repo 'shared.txt') -Value 'main-content' -NoNewline
        git add shared.txt
        git commit -q -m 'seed shared file'
        git checkout -q -b feature/current main
        Set-Content -Path (Join-Path $repo 'shared.txt') -Value 'feature-content' -NoNewline
        git add shared.txt
        git commit -q -m 'diverge shared file on feature branch'
        Set-Content -Path (Join-Path $repo 'shared.txt') -Value 'local-uncommitted-change' -NoNewline

        $output = Remove-GitBranches -DeleteCurrent -Yes *>&1 | Out-String

        $output | Should -Not -Match 'deleted successfully'
        (git branch --show-current) | Should -Be 'feature/current'
        (Get-Content (Join-Path $repo 'shared.txt') -Raw) | Should -Be 'local-uncommitted-change'
    }

    It 'aborts with an error when -DeleteCurrent has no default branch to switch to' {
        git branch -m main trunk
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $repo '.git/refs/remotes/origin/HEAD')
        git checkout -q -b feature/current trunk
        $output = Remove-GitBranches -DeleteCurrent -Yes *>&1 | Out-String
        $output | Should -Match 'default branch'
        (git rev-parse --abbrev-ref HEAD) | Should -Be 'feature/current'
    }

    It 'handles a local branch with a non-ASCII name' {
        New-LocalBranch -Name 'función/日本語'
        $output = Remove-GitBranches -Yes *>&1 | Out-String
        $output | Should -Match ([regex]::Escape('función/日本語'))
        git branch --list 'función/日本語' | Should -BeNullOrEmpty
    }

    # --- Additional behavioral guards ---

    It 'does not claim success when a candidate branch is checked out in a linked worktree, and the branch survives' -Tag 'survive-worktree-checked-out-branch' {
        New-LocalBranch -Name 'orphan/in-worktree'
        $worktree = Join-Path $TestDrive ('linked-wt-' + [guid]::NewGuid().ToString('N'))
        git worktree add -q $worktree 'orphan/in-worktree' 2>$null | Out-Null

        $output = Remove-GitBranches -Yes *>&1 | Out-String

        $output | Should -Not -Match 'deleted successfully'
        git branch --list 'orphan/in-worktree' | Should -Not -BeNullOrEmpty
    }

    It 'aborts instead of reporting a normal outcome when fetch/prune fails against an unreachable remote' -Tag 'abort-on-failed-fetch' {
        git remote set-url origin (Join-Path $TestDrive 'does-not-exist.git')
        $previousPrompt = $env:GIT_TERMINAL_PROMPT
        $env:GIT_TERMINAL_PROMPT = '0'
        try {
            $output = Remove-GitBranches -Yes *>&1 | Out-String
        } finally {
            $env:GIT_TERMINAL_PROMPT = $previousPrompt
        }

        $output | Should -Match 'Failed to fetch'
        $output | Should -Not -Match 'No local branches to delete'
        $output | Should -Not -Match 'deleted successfully'
    }

    It 'does not terminate with an unhandled error when HEAD is detached, stays detached, and still deletes the orphan' -Tag 'survive-detached-head' {
        New-LocalBranch -Name 'orphan/no-remote'
        git checkout -q --detach HEAD

        { Remove-GitBranches -Yes *>&1 | Out-Null } | Should -Not -Throw

        (git rev-parse --abbrev-ref HEAD) | Should -Be 'HEAD'
        git branch --list 'orphan/no-remote' | Should -BeNullOrEmpty
    }

    It 'keeps a branch tracked on a non-origin remote (only remote named upstream)' -Tag 'resolve-non-origin-remote' {
        git remote rename origin upstream
        git branch -q feature/tracked main
        git push -q upstream feature/tracked 2>$null
        git fetch -q upstream 2>$null

        Remove-GitBranches -Yes *>&1 | Out-Null

        git branch --list feature/tracked | Should -Not -BeNullOrEmpty
    }

    It 'does not delete the resolved default branch (origin/HEAD target) when it has no remote counterpart' -Tag 'protect-resolved-default-branch' {
        New-TrackedBranch -Name 'develop'
        New-TrackedBranch -Name 'feature/keep'
        git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
        git checkout -q feature/keep
        git branch -q -D main
        git push -q origin --delete develop 2>$null

        Remove-GitBranches -Yes *>&1 | Out-Null

        git branch --list develop | Should -Not -BeNullOrEmpty
    }

    It "declines deletion when the final prompt is answered 'no', not just 'n'" -Tag 'decline-on-any-n-answer' {
        New-LocalBranch -Name 'orphan/no-remote'
        Mock -ModuleName RemoveGitBranches Read-Host { 'no' }

        $output = Remove-GitBranches *>&1 | Out-String

        $output | Should -Match 'No local branches were deleted'
        git branch --list 'orphan/no-remote' | Should -Not -BeNullOrEmpty
    }

    It 'rejects an unknown parameter at binding and deletes nothing' -Tag 'reject-unknown-flag' {
        New-LocalBranch -Name 'orphan/no-remote'

        { Remove-GitBranches -DryRun -Yes } |
            Should -Throw -ErrorId 'NamedParameterNotFound,Remove-GitBranches'

        git branch --list 'orphan/no-remote' | Should -Not -BeNullOrEmpty
    }

    It 'surfaces failure when an early branch in a multi-branch batch fails to delete' -Tag 'survive-worktree-checked-out-branch' {
        New-LocalBranch -Name 'aaa/in-worktree'
        New-LocalBranch -Name 'zzz/orphan'
        $worktree = Join-Path $TestDrive ('linked-wt-' + [guid]::NewGuid().ToString('N'))
        git worktree add -q $worktree 'aaa/in-worktree' 2>$null | Out-Null

        $output = Remove-GitBranches -Yes *>&1 | Out-String

        $output | Should -Not -Match 'deleted successfully'
        git branch --list 'aaa/in-worktree' | Should -Not -BeNullOrEmpty
        git branch --list 'zzz/orphan' | Should -BeNullOrEmpty
    }

    It 'keeps a branch tracked on origin when a second, alphabetically-earlier remote is also configured' -Tag 'resolve-non-origin-remote' {
        New-TrackedBranch -Name 'feature/tracked'

        $secondRemote = Join-Path $TestDrive ('aremote-' + [guid]::NewGuid().ToString('N') + '.git')
        git init -q --bare $secondRemote | Out-Null
        git remote add aremote $secondRemote
        git fetch -q aremote 2>$null

        Remove-GitBranches -Yes *>&1 | Out-Null

        git branch --list 'feature/tracked' | Should -Not -BeNullOrEmpty
    }

    It 'keeps the current branch (and stays on it) when it is tracked only on a later-sorting remote' -Tag 'resolve-non-origin-remote' {
        $secondRemote = Join-Path $TestDrive ('aaa-' + [guid]::NewGuid().ToString('N') + '.git')
        git init -q --bare $secondRemote | Out-Null
        git remote add aaa $secondRemote
        git fetch -q aaa 2>$null

        New-TrackedBranch -Name 'feature/current'
        git checkout -q feature/current
        New-LocalBranch -Name 'orphan/x'

        Remove-GitBranches -Yes *>&1 | Out-Null

        (git rev-parse --abbrev-ref HEAD) | Should -Be 'feature/current'
        git branch --list 'feature/current' | Should -Not -BeNullOrEmpty
    }
}

Describe 'Remove-GitBranches module initialization' {
    BeforeAll {
        $script:ModuleManifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'RemoveGitBranches.psd1'
        $script:ChildEngine = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell.exe' }

        # PATH with every directory holding a git executable removed. Assigned to
        # the child process only (never to $env:PATH here), so the parent Pester
        # process keeps its own git resolution intact.
        $script:PathWithoutGit = (
            $env:PATH -split [IO.Path]::PathSeparator |
            Where-Object {
                $_ -and -not (
                    Get-ChildItem -Path $_ -Filter 'git.*' -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.BaseName -eq 'git' }
                )
            }
        ) -join [IO.Path]::PathSeparator
    }

    It 'aborts import with a clear error when git is absent from PATH' -Tag 'refuse-load-without-git' {
        $childScript = Join-Path $TestDrive 'import-without-git.ps1'
        @'
param([string]$ManifestPath, [string]$NewPath)
$env:PATH = $NewPath
Import-Module $ManifestPath -Force
'@ | Set-Content -Path $childScript -Encoding utf8

        $stdoutFile = Join-Path $TestDrive 'init-guard.stdout.txt'
        $stderrFile = Join-Path $TestDrive 'init-guard.stderr.txt'

        $childProcess = Start-Process -FilePath $ChildEngine `
            -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $childScript,
                '-ManifestPath', $ModuleManifest, '-NewPath', $PathWithoutGit) `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

        if (-not $childProcess.WaitForExit(30000)) {
            Stop-Process -Id $childProcess.Id -Force -ErrorAction SilentlyContinue
            throw "Child $ChildEngine process did not exit within 30 seconds while importing with git hidden from PATH."
        }

        $childOutput = @(
            (Get-Content -Path $stdoutFile -Raw -ErrorAction SilentlyContinue)
            (Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue)
        ) -join "`n"

        $childOutput | Should -Match 'Git is not installed or not in the system PATH'
    }

    It 'throws (not merely warns) and leaves no usable command when git is absent from PATH' -Tag 'refuse-load-without-git' {
        $childScript = Join-Path $TestDrive 'load-verdict-without-git.ps1'
        @'
param([string]$ManifestPath, [string]$NewPath)
$env:PATH = $NewPath
$imported = $true
try {
    Import-Module $ManifestPath -Force -ErrorAction Stop
} catch {
    $imported = $false
    Write-Output 'RGB_IMPORT_REFUSED'
}
if ($imported) {
    $help = try { Remove-GitBranches -Help *>&1 | Out-String } catch { '' }
    if ($help -match 'USAGE') {
        Write-Output 'RGB_FULLY_USABLE'
    } else {
        Write-Output 'RGB_IMPORTED_NOT_USABLE'
    }
}
'@ | Set-Content -Path $childScript -Encoding utf8

        $stdoutFile = Join-Path $TestDrive 'load-verdict.stdout.txt'
        $stderrFile = Join-Path $TestDrive 'load-verdict.stderr.txt'

        $childProcess = Start-Process -FilePath $ChildEngine `
            -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $childScript,
                '-ManifestPath', $ModuleManifest, '-NewPath', $PathWithoutGit) `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

        if (-not $childProcess.WaitForExit(30000)) {
            Stop-Process -Id $childProcess.Id -Force -ErrorAction SilentlyContinue
            throw "Child $ChildEngine process did not exit within 30 seconds while importing with git hidden from PATH."
        }

        $childOutput = @(
            (Get-Content -Path $stdoutFile -Raw -ErrorAction SilentlyContinue)
            (Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue)
        ) -join "`n"

        $childOutput | Should -Match 'RGB_IMPORT_REFUSED'
        $childOutput | Should -Not -Match 'RGB_FULLY_USABLE'
    }
}
