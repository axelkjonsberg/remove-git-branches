function Invoke-GitCultureInvariant {
    param(
        [Parameter(Mandatory = $true)] [string[]]$Args
    )

    # PS 5.1 with -ErrorAction Stop turns
    # stderr into a terminating NativeCommandError.
    # callers of this function need to check $LASTEXITCODE
    $ErrorActionPreference = 'Continue'

    & git -c core.quotepath=off `
         -c i18n.logOutputEncoding=utf-8 `
         -c i18n.commitEncoding=utf-8 `
         @Args
}
