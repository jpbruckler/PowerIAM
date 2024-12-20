$envSplat = @{
    Name = "PowerIAM"
    Description = "PowerIAM Environment"
    PersistentRunspace = $true
    StartupScript = (Join-Path $PSScriptRoot "..\App\scripts\runspaceStartup.ps1")
}

New-PSUEnvironment @envSplat