<#
.SYNOPSIS
    This is the main build script for the PowerIAM module.
.DESCRIPTION
#>
param(
    [ValidateSet('Major', 'Minor', 'Patch', 'Dev')]
    [string] $ReleaseType = 'Dev'
)

#Include: Settings
$script:ModuleName = [regex]::Match((Get-Item $BuildFile).Name, '^(.*)\.build\.ps1$').Groups[1].Value
. "./$ModuleName.Settings.ps1"



Enter-Build {
    $script:ModuleSourcePath = Join-Path -Path $BuildRoot -ChildPath $script:ModuleName
    $script:ModuleManifestPath = Join-Path -Path $script:ModuleSourcePath -ChildPath "$script:ModuleName.psd1"

    $script:FunctionsToExport = Get-ChildItem (Join-Path -Path $script:ModuleSourcePath -ChildPath 'Public') -Filter '*.ps1' |
        Select-Object -ExpandProperty BaseName

    $script:TestsPath = Join-Path -Path $BuildRoot -ChildPath 'Tests'
    $script:UnitTestsPath = Join-Path -Path $script:TestsPath -ChildPath 'Unit'
    $script:IntegrationTestsPath = Join-Path -Path $script:TestsPath -ChildPath 'Integration'
    $script:coverageThreshold = 30
    $script:testOutputFormat = 'NUnitXML'

    $script:ArtifactsPath = Join-Path -Path $BuildRoot -ChildPath 'Artifacts'
    $script:ArchivePath = Join-Path -Path $BuildRoot -ChildPath 'Archive'
}

task Clean {
    Remove-Item -Path $script:ArtifactsPath -Recurse -Force
    Remove-Item -Path $script:ArchivePath -Recurse -Force

    New-Item -Path $script:ArtifactsPath -ItemType Directory
    New-Item -Path $script:ArchivePath -ItemType Directory
}

task BumpVersion {
    Import-Module -Name PowerShellGet -MinimumVersion 2.2.5
    $script:ModuleManifest = Import-PowerShellDataFile -Path $script:ModuleManifestPath
    $script:ModuleVersion = [version] $script:ModuleManifest.Version

    switch ($ReleaseType) {
        'Major' {
            $NewVersion = '{0}.0.0' -f ($script:ModulVersion.Major + 1)
        }
        'Minor' { $NewVersion = $script:ModuleVersion.Minor + 1 }
        'Patch' { $NewVersion = $script:ModuleVersion.Patch + 1 }
        #'Dev' { $script:NewVersion = $script:ModuleVersion.Patch + 1 }
    }

    $script:NewVersion = [Version]::new(
        $script:NewVersion.Major,
        $script:NewVersion.Minor,
        $script:NewVersion.Patch
    )
    $script:ModuleManifest.Version = $script:NewVersion
    $script:ModuleManifest | Export-PowerShellDataFile -Path $script:ModuleManifestPath -Force
}