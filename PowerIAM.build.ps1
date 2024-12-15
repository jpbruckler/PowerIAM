<#
.SYNOPSIS
    This is the main build script for the PowerIAM module.
.DESCRIPTION
#>

#Include: Settings
$script:ModuleName = [regex]::Match((Get-Item $BuildFile).Name, '^(.*)\.build\.ps1$').Groups[1].Value
. "./$ModuleName.Settings.ps1"

Enter-Build {
    $script:ModuleSourcePath = Join-Path -Path $BuildRoot -ChildPath $script:ModuleName
}