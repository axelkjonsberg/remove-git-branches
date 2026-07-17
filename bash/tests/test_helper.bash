#!/usr/bin/env bash
# Shared fixtures for the bats suite. Builds a real bare "origin" repository
# plus a local clone under BATS_TEST_TMPDIR, so tests exercise actual git
# plumbing (fetch/prune, refs, branch switching) instead of mocking git.

# shellcheck disable=SC2034 # consumed by the .bats files that `load` this helper
SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../remove-git-branches.sh"

setup_repo() {
  remote_dir="${BATS_TEST_TMPDIR}/origin.git"
  seed_dir="${BATS_TEST_TMPDIR}/seed"
  local_dir="${BATS_TEST_TMPDIR}/work"

  git init -q --bare -b main "$remote_dir"

  git init -q -b main "$seed_dir"
  (
    cd "$seed_dir" || exit 1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false
    git commit -q --allow-empty -m init
    git remote add origin "$remote_dir"
    git push -q origin main
  )
  rm -rf "$seed_dir"

  git clone -q "$remote_dir" "$local_dir"
  cd "$local_dir" || return 1
  git config user.email "test@example.com"
  git config user.name "Test User"
  git config commit.gpgsign false
}

# A local branch that never had a remote counterpart.
create_local_branch() {
  git branch -q "$1" main
}

# A branch pushed to origin, so it currently has a remote counterpart.
create_tracked_branch() {
  git branch -q "$1" main
  git push -q origin "$1"
}
