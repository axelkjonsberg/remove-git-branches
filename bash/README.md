# RGB for Bash

Place this script anywhere and add an alias to it in your _.bashrc_ or _.zshrc_:

```bash
alias remove_git_branches='absolute/path/to/remove-git-branches.sh'
alias rgb='absolute/path/to/remove-git-branches.sh'
```

If you are using Git Bash, Cygwin, or Windows Subsystem for Linux (WSL) on Windows, you would place your .bashrc file in your home directory.

**Git Bash** or **Cygwin** do not create a .bashrc file by default; create this file yourself if it does not already exist. This can be done with `touch ~/.bashrc` in a new terminal.

In **WSL**, the .bashrc file should be located in your home directory (/home/\<username>/.bashrc).

If you get a permission error, enable execution of the script with:

```bash
sudo chmod +x ./remove-git-branches.sh
```
