# specify the minimum required major PowerShell version that the build script should validate
[version]$script:requiredPSVersion = '7.0.0'

function Test-ManifestBool ($Path) {
    Get-ChildItem $Path | Test-ModuleManifest -ErrorAction SilentlyContinue | Out-Null; $?
}