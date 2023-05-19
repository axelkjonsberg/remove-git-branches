# RGB – Shell command for removing unused Git branches

![License_badge](https://img.shields.io/github/license/axelkjonsberg/remove-git-branches?style=flat-square)

A shortcut terminal command for removing all local Git branches which do not have a corresponding remote.

Fetches and prunes remote branches.
If a local branch does not have any existing remote, remove it!

The command will list all the branches it wants to delete and ask the user for confirmation.
The command will also ask the user if they would like to delete their current branch (if they are not allready on 'main' or 'master'). 
