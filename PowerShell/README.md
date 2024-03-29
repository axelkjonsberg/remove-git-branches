# RGB for Powershell

## Installation

### Using PowerShell Gallery

To install _RemoveGitBranches_,  use `Install-Module -Name RemoveGitBranches`.

More info on the module can be found at its [PowerShell Gallery page](https://www.powershellgallery.com/packages/RemoveGitBranches).

### Manually add to PowerShell profile

You can add the `Remove-GitBranches` module to your PowerShell profile so that it is available whenever you start a new session.

The profile file is typically found at: `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`.

If this file does not exist, you can create it.

Here are the steps to add the function to your profile:

1. Open your profile file with a text editor (e.g., `notepad $PROFILE` or `code $PROFILE`).
2. Add the Remove-LocalBranches function to the file and save it.
3. Close and reopen your PowerShell terminal.
