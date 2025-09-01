# Remove-GitBranches (rgb) for PowerShell

## Description

The `Remove-GitBranches` command is designed to safely delete local Git branches that no longer have a remote counterpart.

- The command identifies and deletes local Git branches that are not present on the remote repository.
- It excludes `master` and `main` branches from deletion.
- Ensures proper handling of branch names with special characters by temporarily setting the encoding to UTF-8.

---

## Usage

```ps
Remove-GitBranches
```

### Options

- Adding the flag **`-Help`** will display information about the command.

## Installation

### Using PowerShell Gallery

To install _RemoveGitBranches_, use `Install-Module -Name RemoveGitBranches`.

More info on the module can be found at its [PowerShell Gallery page](https://www.powershellgallery.com/packages/RemoveGitBranches).

### Manually add to PowerShell profile

You can add the `Remove-GitBranches` module to your PowerShell profile so that it is available whenever you start a new session.

The profile file is typically found at: `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`.

If this file does not exist, you can create it.

Here are the steps to add the function to your profile:

1. Open your profile file with a text editor (e.g., `notepad $PROFILE` or `code $PROFILE`).
2. Add the Remove-LocalBranches function to the file and save it.
3. Close and reopen your PowerShell terminal.

## Behavior

1. **Remote Sync**: Fetches the latest updates from the remote repository.
2. **Branch Filtering**:
   - Identifies branches missing on the remote.
   - Excludes `master` and `main` branches from deletion.
   - If the checked out branch also is missing a remote counterpart, the user is prompted to confirm deletion of the current branch.
3. **Branch Switching**:
   - Automatically switches to `master` or `main` if the current branch is deleted.
   - Fails safely if neither `master` nor `main` exists.
4. **Deletion Confirmation**:
   - Prompts the user before deleting branches.
5. **UTF-8 Handling**:
   - Temporarily sets UTF-8 encoding for the current PowerShell console in order to handle non-ASCII branch names.
