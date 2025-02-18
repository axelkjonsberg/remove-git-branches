#!/bin/bash

function git-culture-invariant {
    git -c core.quotepath=off \
        -c i18n.logOutputEncoding=utf-8 \
        -c i18n.commitEncoding=utf-8 "$@"
}

function branch-exists {
    git-culture-invariant show-ref --verify --quiet refs/heads/$1
    return $?
}

function has-remote {
    git-culture-invariant show-ref --verify --quiet refs/remotes/origin/$1
    return $?
}

function branch-exists {
    git-culture-invariant show-ref --verify --quiet refs/heads/$1
    return $?
}

function has-remote {
    git-culture-invariant show-ref --verify --quiet refs/remotes/origin/$1
    return $?
}

function remove-git-branches {    
    delete_current=$1

    is_inside_work_tree=$(git-culture-invariant rev-parse --is-inside-work-tree)

    if [[ ! $is_inside_work_tree ]]; then
        printf "\e[0;31mNot inside a Git repository\e[0m\n"
        return 1
    fi

    git-culture-invariant fetch -p

    current_branch=$(git-culture-invariant symbolic-ref --short -q HEAD | xargs)

    default_branch=''
    if branch-exists 'master'; then
        default_branch='master'
    elif branch-exists 'main'; then
        default_branch='main'
    fi

    has-remote "$current_branch"
    remote_exists=$?

    if [[ -z "$delete_current" && -n "$default_branch" && "$current_branch" != "$default_branch" && $remote_exists -ne 0 ]]; then
        read -p "Current local branch '$current_branch' has no remote; delete this and switch to '$default_branch'? (Y/n): " choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        delete_current=$([[ "$choice" == "n" ]] && echo "false" || echo "true")
    fi

    if [[ $delete_current == true && "$current_branch" != "$default_branch" && -z "$default_branch" ]]; then
        printf "\e[0;31mNeither 'main' nor 'master' branches exist. Cannot switch branches after deleting current.\e[0m\n"
        return 1
    fi

    local_branches=($(git-culture-invariant branch | sed 's/\* //'))
    remote_branches=($(git-culture-invariant branch -r | sed 's/origin\///g' | sed 's/HEAD -> //' | sort -u))

    branches_to_delete=()
    for branch in "${local_branches[@]}"; do
        if [[ ! " ${remote_branches[*]} " =~ " ${branch} " ]] && \
            [ "$branch" != "master" ] && [ "$branch" != "main" ] && \
            { [ "$branch" != "$current_branch" ] || [ "$delete_current" == true ]; }; then
            branches_to_delete+=("$branch")
        fi
    done

    if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
        printf "\e[0;36mNo local branches to delete\e[0m\n"
        return 0
    fi

    printf "\e[0;33mThe following local Git branches will be deleted:\e[0m\n"
    for branch in "${branches_to_delete[@]}"; do
        echo -e "\e[35m  - $branch\e[0m"
    done

    read -p "Are you sure you want to delete these local branches? (Y/n): " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    if [[ "$choice" == "n" ]]; then
        printf "\e[0;36mNo local branches were deleted\e[0m\n"
        exit 0
    fi


    if [[ $delete_current == true && "$current_branch" != "$default_branch" ]]; then
        git-culture-invariant switch $default_branch
    fi

    for branch in "${branches_to_delete[@]}"; do
        git-culture-invariant branch -D "$branch"
    done

    printf "\e[0;32mThe local branches were deleted successfully\e[0m\n"
}

remove-git-branches $1
