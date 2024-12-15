#Include: Settings
$ModuleName = [regex]::Match((Get-Item $BuildFile).Name, '^(.*)\.build\.ps1$').Groups[1].Value
. "./$ModuleName.Settings.ps1"