#!/usr/bin/env bash

git-culture-invariant() {
  LANG=C.UTF-8 LC_ALL=C.UTF-8 \
  git -c core.quotepath=off \
      -c i18n.logOutputEncoding=utf-8 \
      -c i18n.commitEncoding=utf-8 "$@"
}

branch-exists() {
  git-culture-invariant show-ref --verify --quiet "refs/heads/$1"
}

has-remote() {
  git-culture-invariant for-each-ref --format='%(refname:lstrip=3)' refs/remotes | grep -qxF "$1"
}

remove-git-branches() {
  delete_current=false
  assume_yes=false

  while (($#)); do
    case "$1" in
      --delete-current) delete_current=true ;;
      -y|--yes)         assume_yes=true ;;
      -h|--help)
        cat <<-'EOF'
remove-git-branches
Safely delete local branches that no longer exist on the remote.

USAGE
  remove-git-branches [--delete-current] [-y|--yes]

OPTIONS
  --delete-current   Also delete the current branch (if it has no remote).
  -y, --yes          Skip confirmation prompts.
  -h, --help         Show this help.
EOF
        return 0
        ;;
      *)
        printf "\e[0;31mUnknown option '%s'\e[0m\n" "$1"
        return 2
        ;;
    esac
    shift
  done

  if ! command -v git >/dev/null 2>&1; then
    printf "\e[0;31mGit is not installed or not in the system PATH\e[0m\n"
    return 1
  fi

  if ! git-culture-invariant rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf "\e[0;31mNot inside a Git repository\e[0m\n"
    return 1
  fi

  if ! git-culture-invariant fetch -p; then
    printf "\e[0;31mFailed to fetch from the remote; aborting without deleting anything.\e[0m\n"
    return 1
  fi

  # current branch
  read -r current_branch < <(git-culture-invariant symbolic-ref --short -q HEAD)

  # default branch: local master/main, else origin/HEAD target
  default_branch=""
  if branch-exists master; then
    default_branch=master
  elif branch-exists main; then
    default_branch=main
  else
    if remote_head=$(git-culture-invariant symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null); then
      candidate=${remote_head#origin/}
      # Only treat it as the default if the branch actually exists locally;
      # otherwise switching to it would silently DWIM-create it from the remote.
      if branch-exists "$candidate"; then
        default_branch=$candidate
      fi
    fi
  fi

  # decide whether to delete current branch if it has no remote
  if [[ -n $current_branch ]] && ! has-remote "$current_branch" \
     && [[ -n $default_branch && $current_branch != "$default_branch" && $delete_current == false ]]; then
    if [[ $assume_yes == true ]]; then
      delete_current=true
    else
      if read -r -p "Current local branch '$current_branch' has no remote; delete this and switch to '$default_branch'? (Y/n): " choice; then
        choice=${choice,,}
        delete_current=$([[ $choice == n* ]] && echo false || echo true)
      else
        delete_current=false
      fi
    fi
  fi

  if [[ $delete_current == true && -z $default_branch ]]; then
    printf "\e[0;31mNo 'main' or 'master' (or origin/HEAD) to switch to after deleting current.\e[0m\n"
    return 1
  fi

  mapfile -t local_branches < <(
    git-culture-invariant for-each-ref --format='%(refname:short)' refs/heads
  )
  mapfile -t remote_branches < <(
    git-culture-invariant for-each-ref --format='%(refname:lstrip=3)' refs/remotes |
    grep -v '^HEAD$'
  )

  declare -A remote_set=()
  for rb in "${remote_branches[@]}"; do remote_set["$rb"]=1; done

  branches_to_delete=()
  for branch in "${local_branches[@]}"; do
    if [[ -z ${remote_set[$branch]} ]] && [[ ${branch,,} != master && ${branch,,} != main ]] && \
       [[ -z $default_branch || $branch != "$default_branch" ]] && \
       { [[ $branch != "$current_branch" ]] || [[ $delete_current == true ]]; }; then
      branches_to_delete+=("$branch")
    fi
  done

  if (( ${#branches_to_delete[@]} == 0 )); then
    printf "\e[0;36mNo local branches to delete\e[0m\n"
    return 0
  fi

  printf "\e[0;33mThe following local Git branches will be deleted:\e[0m\n"
  for branch in "${branches_to_delete[@]}"; do
    printf "\e[35m  - %s\e[0m\n" "$branch"
  done

  if [[ $assume_yes != true ]]; then
    if ! read -r -p "Delete these local branches? (Y/n): " choice || [[ ${choice,,} == n* ]]; then
      printf "\e[0;36mNo local branches were deleted\e[0m\n"
      return 0
    fi
  fi

  if [[ $delete_current == true && $current_branch != "$default_branch" ]]; then
    if ! git-culture-invariant switch "$default_branch" 2>/dev/null \
       && ! git-culture-invariant checkout "$default_branch"; then
      printf "\e[0;31mFailed to switch to '%s'; no branches were deleted.\e[0m\n" "$default_branch"
      return 1
    fi
  fi

  delete_failed=false
  for branch in "${branches_to_delete[@]}"; do
    if ! git-culture-invariant branch -D "$branch"; then
      delete_failed=true
    fi
  done

  if [[ $delete_failed == true ]]; then
    printf "\e[0;31mSome local branches could not be deleted\e[0m\n"
    return 1
  fi

  printf "\e[0;32mThe local branches were deleted successfully\e[0m\n"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  remove-git-branches "$@"
fi
