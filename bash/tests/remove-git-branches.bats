#!/usr/bin/env bats

load 'test_helper'

setup() {
  setup_repo
}

@test "--help prints usage without requiring a git repository" {
  cd "$BATS_TEST_TMPDIR"
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "fails outside a git repository" {
  outside="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$outside"
  cd "$outside"
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not inside a Git repository"* ]]
}

@test "reports nothing to delete when only the default branch exists" {
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No local branches to delete"* ]]
}

@test "deletes a local branch that never had a remote" {
  create_local_branch "orphan/no-remote"
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 0 ]
  run git branch --list "orphan/no-remote"
  [ -z "$output" ]
}

@test "fetches and prunes, then deletes a branch whose remote counterpart was removed" {
  create_tracked_branch "feature/merged"
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 0 ]
  run git branch --list "feature/merged"
  [[ "$output" == *"feature/merged"* ]]

  git push -q origin --delete feature/merged

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 0 ]
  run git branch --list "feature/merged"
  [ -z "$output" ]
}

@test "never deletes a local branch named master, even without a remote" {
  git branch -q master main
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 0 ]
  run git branch --list master
  [[ "$output" == *"master"* ]]
}

@test "does not delete the current branch by default when declined" {
  git checkout -q -b feature/current main
  run bash -c "source '$SCRIPT_UNDER_TEST'; printf 'n\n' | remove-git-branches"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No local branches to delete"* ]]
  run git branch --list feature/current
  [[ "$output" == *"feature/current"* ]]
}

@test "confirms current-branch deletion, switches to default branch, then deletes it" {
  git checkout -q -b feature/current main
  run bash -c "source '$SCRIPT_UNDER_TEST'; printf 'y\ny\n' | remove-git-branches"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted successfully"* ]]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]
  run git branch --list feature/current
  [ -z "$output" ]
}

@test "--yes deletes the current branch without prompting" {
  git checkout -q -b feature/current main
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]
  run git branch --list feature/current
  [ -z "$output" ]
}

@test "--delete-current skips the first prompt but still confirms deletion" {
  git checkout -q -b feature/current main
  run bash -c "source '$SCRIPT_UNDER_TEST'; printf 'y\n' | remove-git-branches --delete-current"
  [ "$status" -eq 0 ]
  run git branch --list feature/current
  [ -z "$output" ]
}

@test "does not claim success and leaves the current branch untouched when the switch to default fails" {
  printf 'main-content' > shared.txt
  git add shared.txt
  git commit -q -m "seed shared file"
  git checkout -q -b feature/current main
  printf 'feature-content' > shared.txt
  git add shared.txt
  git commit -q -m "diverge shared file on feature branch"
  printf 'local-uncommitted-change' > shared.txt

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --delete-current --yes"

  [ "$status" -ne 0 ]
  [[ "$output" != *"deleted successfully"* ]]
  [ "$(git branch --show-current)" = "feature/current" ]
  [ "$(cat shared.txt)" = "local-uncommitted-change" ]
}

@test "aborts with an error when --delete-current has no default branch to switch to" {
  git branch -m main trunk
  rm -f .git/refs/remotes/origin/HEAD
  git checkout -q -b feature/current trunk

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --delete-current --yes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No 'main' or 'master'"* ]]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "feature/current" ]
}

@test "handles a local branch with a non-ASCII name" {
  create_local_branch "función/日本語"
  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"función/日本語"* ]]
  run git branch --list "función/日本語"
  [ -z "$output" ]
}

# bats test_tags=guard-execution-on-source
@test "sourcing the script alone defines functions but runs nothing" {
  create_local_branch "orphan/no-remote"
  before_branches=$(git for-each-ref --format='%(refname:short)' refs/heads | sort)

  run bash -c "source '$SCRIPT_UNDER_TEST'" < /dev/null

  [ "$status" -eq 0 ]
  [ -z "$output" ]

  after_branches=$(git for-each-ref --format='%(refname:short)' refs/heads | sort)
  [ "$after_branches" = "$before_branches" ]
}

# --- Additional behavioral guards ---

# bats test_tags=survive-worktree-checked-out-branch
@test "does not claim success when a candidate branch is checked out in a linked worktree, and the branch survives" {
  create_local_branch "orphan/in-worktree"
  git worktree add -q "$BATS_TEST_TMPDIR/linked-wt" "orphan/in-worktree"

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [[ "$output" != *"deleted successfully"* ]]
  run git branch --list "orphan/in-worktree"
  [[ "$output" == *"orphan/in-worktree"* ]]
}

# bats test_tags=abort-on-failed-fetch
@test "aborts instead of reporting a normal outcome when fetch/prune fails against an unreachable remote" {
  git remote set-url origin "$BATS_TEST_TMPDIR/does-not-exist.git"

  GIT_TERMINAL_PROMPT=0 run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [ "$status" -ne 0 ]
  [[ "$output" != *"No local branches to delete"* ]]
  [[ "$output" != *"deleted successfully"* ]]
}

# bats test_tags=survive-detached-head
@test "detached HEAD: does not silently switch away from the detached commit" {
  create_local_branch "orphan/no-remote"
  git checkout -q --detach HEAD

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "HEAD" ]
  run git branch --list "orphan/no-remote"
  [ -z "$output" ]
}

# bats test_tags=resolve-non-origin-remote
@test "keeps a branch tracked on a non-origin remote (only remote named 'upstream')" {
  git remote rename origin upstream
  git branch -q feature/tracked main
  git push -q upstream feature/tracked
  git fetch -q upstream

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [ "$status" -eq 0 ]
  run git branch --list feature/tracked
  [[ "$output" == *"feature/tracked"* ]]
}

# bats test_tags=protect-resolved-default-branch
@test "does not delete the resolved default branch (origin/HEAD target) when it has no remote counterpart" {
  create_tracked_branch "develop"
  create_tracked_branch "feature/keep"
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
  git checkout -q feature/keep
  git branch -q -D main
  git push -q origin --delete develop

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  run git branch --list develop
  [[ "$output" == *"develop"* ]]
}

# bats test_tags=decline-on-any-n-answer
@test "declines deletion when the final prompt is answered 'no', not just 'n'" {
  create_local_branch "orphan/no-remote"

  run bash -c "source '$SCRIPT_UNDER_TEST'; printf 'no\n' | remove-git-branches"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No local branches were deleted"* ]]
  run git branch --list "orphan/no-remote"
  [[ "$output" == *"orphan/no-remote"* ]]
}

# bats test_tags=decline-on-closed-stdin
@test "closed stdin without --yes declines deletion instead of proceeding" {
  create_local_branch "orphan/no-remote"

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches < /dev/null"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No local branches were deleted"* ]]
  run git branch --list "orphan/no-remote"
  [[ "$output" == *"orphan/no-remote"* ]]
}

# bats test_tags=reject-unknown-flag
@test "unknown flag is rejected: errors, deletes nothing, does not silently proceed" {
  create_local_branch "orphan/no-remote"

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --dry-run" </dev/null

  [ "$status" -ne 0 ]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" != *"deleted successfully"* ]]
  run git branch --list "orphan/no-remote"
  [[ "$output" == *"orphan/no-remote"* ]]
}


# bats test_tags=survive-worktree-checked-out-branch
@test "does not claim success when the FIRST of several candidate branches fails to delete, though it sorts before a deletable one" {
  create_local_branch "aaa/in-worktree"
  git worktree add -q "$BATS_TEST_TMPDIR/linked-wt" "aaa/in-worktree"
  create_local_branch "zzz/orphan"

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [ "$status" -ne 0 ]
  [[ "$output" != *"deleted successfully"* ]]
  run git branch --list "aaa/in-worktree"
  [[ "$output" == *"aaa/in-worktree"* ]]
  run git branch --list "zzz/orphan"
  [ -z "$output" ]
}

# bats test_tags=resolve-non-origin-remote
@test "keeps a branch tracked on 'origin' when a second remote sorts before it alphabetically" {
  git init -q --bare "${BATS_TEST_TMPDIR}/backup.git"
  git remote add backup "${BATS_TEST_TMPDIR}/backup.git"
  git fetch -q backup

  create_tracked_branch "feature-a"

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [ "$status" -eq 0 ]
  run git branch --list feature-a
  [[ "$output" == *"feature-a"* ]]
}

# bats test_tags=resolve-non-origin-remote
@test "keeps the current branch (and stays on it) when it is tracked only on a later-sorting remote" {
  git init -q --bare "${BATS_TEST_TMPDIR}/aaa.git"
  git remote add aaa "${BATS_TEST_TMPDIR}/aaa.git"
  git fetch -q aaa

  create_tracked_branch "feature-current"
  git checkout -q feature-current
  create_local_branch "orphan/x"

  run bash -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [ "$status" -eq 0 ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "feature-current" ]
  run git branch --list feature-current
  [[ "$output" == *"feature-current"* ]]
}

# bats test_tags=bash-missing-git-preflight-guard
@test "fails with a clear diagnostic when git is not on PATH, instead of a raw command-not-found or the generic not-a-repo message" {
  git_dir=$(dirname "$(command -v git)")
  scrubbed_path=""
  IFS=':' read -ra path_entries <<< "$PATH"
  for entry in "${path_entries[@]}"; do
    [ "$entry" = "$git_dir" ] && continue
    if [ -x "$entry/git" ] || [ -x "$entry/git.exe" ]; then
      continue
    fi
    scrubbed_path="${scrubbed_path:+$scrubbed_path:}$entry"
  done

  bash_path="$(command -v bash)"
  run env PATH="$scrubbed_path" "$bash_path" -c "source '$SCRIPT_UNDER_TEST'; remove-git-branches --yes"

  [ "$status" -ne 0 ]
  [[ "$output" =~ [Gg]it.*not\ installed || "$output" =~ [Nn]ot\ in.*PATH ]]
  [[ "$output" != *"Not inside a Git repository"* ]]
}
