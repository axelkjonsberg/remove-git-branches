function Invoke-GitCultureInvariant {
    param(
        [Parameter(Mandatory = $true)] [string[]]$Args
    )

    & git -c core.quotepath=off `
         -c i18n.logOutputEncoding=utf-8 `
         @Args
}
