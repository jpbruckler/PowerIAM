param(
    [string] $Environment = 'dev',
    [string] $Tasks = 'build'
)
. .\src\PowerIAM.Settings.ps1

infisical login

infisical run --env=$Environment -- pwsh.exe -NoProdile -File .\PowerIAM.build.ps1 -Environment $Environment -Tasks ($Tasks -join ' ')