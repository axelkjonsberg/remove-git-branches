#!/bin/bash

function branch-exists {
    git show-ref --verify --quiet refs/heads/$1
}

function remove-git-branches {
    delete_current=$1

    is_inside_work_tree=$(git rev-parse --is-inside-work-tree)

    if [[ ! $is_inside_work_tree ]]; then
        printf "\e[0;31mNot inside a Git repository\e[0m\n"
        exit 1
    fi

    git fetch -p

    current_branch=$(git symbolic-ref --short -q HEAD | xargs)

    if branch-exists 'master'; then
        default_branch='master'
    elif branch-exists 'main'; then
        default_branch='main'
    fi

    if [[ -z "$delete_current" && -n "$default_branch" && "$current_branch" != "$default_branch" ]]; then
        read -p "Also delete current branch $current_branch and switch to $default_branch? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            delete_current=true
        fi
    fi

    if [[ -n "$delete_current" && "$current_branch" != "$default_branch" && -z "$default_branch" ]]; then
        printf "\e[0;31mNeither 'main' nor 'master' branches exist. Cannot switch branches after deleting current.\e[0m\n"
        exit 1
    fi

    local_branches=($(git branch | sed 's/\* //'))

    remote_branches=($(git branch -r | sed 's/origin\///g' | sed 's/HEAD -> //' | sort -u))

    branches_to_delete=()
    for branch in "${local_branches[@]}"; do
        if [[ ! " ${remote_branches[*]} " =~ " ${branch} " ]] && \
            [ "$branch" != "master" ] && [ "$branch" != "main" ] && \
            { [ "$branch" != "$current_branch" ] || [ "$delete_current" = true ]; }; then
            branches_to_delete+=("$branch")
        fi
    done

    if [[ -z "$branches_to_delete" ]]; then
        printf "\e[0;36mNo branches to delete\e[0m\n"
        exit 0
    fi

    printf "\e[0;33mThe following local Git branches will be deleted:\e[0m\n"

    for branch in "${branches_to_delete[@]}"; do
        echo -e "\e[35m  - $branch\e[0m"
    done

    read -p "Are you sure you want to delete these branches? (y/N): " choice

    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        printf "\e[0;36mNo branches were deleted\e[0m\n"
        exit 0
    fi

    if [[ -n "$delete_current" && "$current_branch" != "$default_branch" ]]; then
        git switch $default_branch
    fi

    for branch in $branches_to_delete; do
        git branch -D $branch
    done

    printf "\e[0;32mThe branches were deleted successfully\e[0m\n"
}

remove-git-branches $1
