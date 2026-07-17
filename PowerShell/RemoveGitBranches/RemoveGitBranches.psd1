@{
    ModuleVersion           = '1.1.5'
    GUID                    = '615a69f2-12da-4a41-ae0a-9099a809ff22'
    Author                  = 'Axel M. Kjønsberg'
    Description             = 'Safely remove unused local Git branches by comparing local branches to branches in the remote repository.'
    PowerShellVersion       = '5.1'
    CompatiblePSEditions    = @('Desktop', 'Core')
    RootModule              = 'RemoveGitBranches.psm1'
    FunctionsToExport       = @('Remove-GitBranches')
    AliasesToExport         = @('rgb')
    ScriptsToProcess        = @('Scripts\Initialize.ps1')
    PrivateData             = @{
        PSData = @{
            Tags            = 'git', 'cleanup', 'branch', 'powershell', 'automation'
            ProjectUri      = 'https://github.com/axelkjonsberg/remove-git-branches'
            LicenseUri      = 'https://github.com/axelkjonsberg/remove-git-branches/blob/master/LICENSE'
            ReleaseNotes    = 'https://github.com/axelkjonsberg/remove-git-branches/releases'
        }
    }
}
