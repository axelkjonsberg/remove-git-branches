@{
    ModuleVersion           = '1.1.1'
    GUID                    = '615a69f2-12da-4a41-ae0a-9099a809ff22'
    Author                  = 'Axel M. Kjønsberg'
    Description             = 'Efficiently remove unused local Git branches by comparing them to remote repo.'
    PowerShellVersion       = '5.1'
    CompatiblePSEditions    = @('Desktop', 'Core')
    RootModule              = 'src/RemoveGitBranches.psm1'
    FunctionsToExport       = @('Remove-GitBranches')
    AliasesToExport         = @('rgb')
    PrivateData             = @{
        PSData = @{
            Tags            = 'git', 'cleanup', 'branch', 'powershell'
            ProjectUri      = 'https://github.com/axelkjonsberg/remove-git-branches'
            LicenseUri      = 'https://github.com/axelkjonsberg/remove-git-branches/blob/main/LICENSE'
            ReleaseNotes    = 'https://github.com/axelkjonsberg/remove-git-branches/releases'
        }
    }
}
