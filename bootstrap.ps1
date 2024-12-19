$InformationPreference = 'Continue'

# https://docs.microsoft.com/powershell/module/packagemanagement/get-packageprovider
Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null

# https://docs.microsoft.com/powershell/module/powershellget/set-psrepository
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# List of PowerShell Modules required for the build
$modulesToInstall = New-Object System.Collections.Generic.List[object]

# https://github.com/pester/Pester
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'Pester'
            ModuleVersion = '5.6.1'
        }))

# https://github.com/nightroman/Invoke-Build
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'InvokeBuild'
            ModuleVersion = '5.11.3'
        }))

# https://github.com/PowerShell/PSScriptAnalyzer
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'PSScriptAnalyzer'
            ModuleVersion = '1.22.0'
        }))

# https://github.com/PowerShell/platyPS
# older version used due to: https://github.com/PowerShell/platyPS/issues/457
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'platyPS'
            ModuleVersion = '0.12.0'
        }))

# https://github.com/nightroman/PsdKit
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'PsdKit'
            ModuleVersion = '0.6.3'
        }))

# https://github.com/nightroman/Psd
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'PSHTML'
            ModuleVersion = '0.8.2'
        }))

# https://psframework.org
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'PSFramework'
            ModuleVersion = '1.12.346'
        }))

# https://github.com/PowerShell/SecretManagement
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'Microsoft.PowerShell.SecretManagement'
            ModuleVersion = '1.1.2'
        }))

# https://github.com/PowerShell/SecretStore
[void]$modulesToInstall.Add(([PSCustomObject]@{
            ModuleName    = 'Microsoft.PowerShell.SecretStore'
            ModuleVersion = '1.0.6'
        }))

$OldPester = Get-Module -ListAvailable pester | Where-Object { $_.Version -lt [version]'4.0.0' }
if ($OldPester) {
    Write-Warning 'A legacy version of Pester has been found. It is suggested to remove this version.'

    Write-Warning @'
Run the following as administrator:

$module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
& takeown.exe /F $module /A /R
& icacls.exe $module /reset
& icacls.exe $module /grant "*S-1-5-32-544:F" /inheritance:d /T
Remove-Item -Path $module -Recurse -Force -Confirm:$false
'@
}

Write-Information 'Installing PowerShell Modules' -InformationAction Continue
foreach ($module in $modulesToInstall) {
    $moduleCheck = Get-Module -Name $module.ModuleName -ListAvailable -ErrorAction SilentlyContinue | Select-Object Version | Sort-Object
    if ($moduleCheck -and $moduleCheck.Version -ge [version]$module.ModuleVersion) {
        '  - {0} version {1} is already installed' -f $module.ModuleName, $module.ModuleVersion
        continue
    }
    $installSplat = @{
        Name               = $module.ModuleName
        RequiredVersion    = $module.ModuleVersion
        Repository         = 'PSGallery'
        SkipPublisherCheck = $true
        Force              = $true
        ErrorAction        = 'Stop'
    }
    try {
        if ($module.ModuleName -eq 'Pester' -and $IsWindows) {
            # special case for Pester certificate mismatch with older Pester versions - https://github.com/pester/Pester/issues/2389
            # this only affects windows builds
            Install-Module @installSplat -SkipPublisherCheck
        }
        else {
            Install-Module @installSplat
        }
        Import-Module -Name $module.ModuleName -ErrorAction Stop
        '  - Successfully installed {0} version {1}' -f $module.ModuleName, $module.ModuleVersion
    }
    catch {
        $message = 'Failed to install {0} version {1}' -f $module.ModuleName, $module.ModuleVersion
        "  - $message"
        throw
    }
}

Write-Information 'Installing Python3, pip, and mkdocs. You will be prompted for admin consent...' -InformationAction Continue

try {
    Write-Information 'Installing Microsoft Build tools...'
    $uri = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    $outFile = (Join-Path $env:TEMP 'vs_BuildTools.exe')
    Invoke-WebRequest -Uri $uri -OutFile $outFile -UseBasicParsing
    $result = Start-Process $outFile -ArgumentList '--add Microsoft.VisualStudio.Workload.MSBuildTools --includeRecommended --add Microsoft.VisualStudio.Workload.VCTools --passive --nocache --installWhileDownloading' -Wait -PassThru

    $result = Start-Process winget -ArgumentList 'install python3 --accept-package-agreements --accept-source-agreements --silent --force' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install Python3'
    }
    Write-Information '  - Successfully installed Python3'

    $result = Start-Process python -ArgumentList '-m pip install --upgrade pip' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install pip'
    }
    Write-Information '  - Successfully installed pip'

    $result = Start-Process pip -ArgumentList 'install mkdocs mkdocs-material' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install mkdocs'
    }
    Write-Information '  - Successfully installed mkdocs'

    $result = Start-Process pip -ArgumentList 'install -r requirements.txt' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install mkdocs requirements'
    }
    Write-Information '  - Successfully installed mkdocs requirements'
}
catch {
    $message = 'Failed to install Python3, pip, and mkdocs'
    Write-Host -ForegroundColor Red -Object $message
    exit 1
}

if (-not (Get-Command git-cliff -ErrorAction SilentlyContinue)) {
    $installGitCliff = Read-Host -Prompt 'Would you like to install git-cliff? (y/n)'

    if ($installGitCliff.ToLower() -eq 'y') {
        $latest = Invoke-RestMethod -Uri 'api.github.com/repos/orhun/git-cliff/releases/latest'
        $target = $latest.assets | Where-Object name -Like '*-windows-gnu.zip' | Select-Object -First 1
        $url = $target.browser_download_url

        Write-Information 'Downloading git-cliff' -InformationAction Continue
        $temp = [System.IO.Path]::GetTempFileName()
        Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing
        Expand-Archive -Path $temp -DestinationPath "$env:LocalAppData" -Force
        $gcPath = (Resolve-Path "$env:LOCALAPPDATA\git-cliff*").Path
        Rename-Item $gcPath -NewName 'git-cliff' -Force

        if (-not ($env:Path -match 'git-cliff')) {
            $newPath = "$env:LOCALAPPDATA\git-cliff"
            $env:path = $env:path + ';' + $newPath
            $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
            $newPath = $currentPath + ';' + $newPath
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        }

        if (Get-Command git-cliff -ErrorAction SilentlyContinue) {
            Write-Information ('  - Successfully installed git-cliff to {0}' -f "$env:LOCALAPPDATA\git-cliff")
        }
        else {
            Write-Error 'Failed to install git-cliff'
            exit 1
        }
        git-cliff --init
    }
}

if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) {
    $installInfisical = Read-Host -Prompt 'Would you like to install Infisical [this will install Scoop]? (y/n)'

    if ($installInfisical.ToLower() -eq 'y') {
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Information 'Installing Scoop...'
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        }
        else {
            Write-Information 'Updating Scoop...'
            scoop update
        }


        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to install Scoop'
        }
        Write-Information '  - Successfully installed Scoop'

        scoop bucket add org https://github.com/Infisical/scoop-infisical.git
        scoop install infisical
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to install Infisical'
        }
        Write-Information '  - Successfully installed Infisical'
    }
}

Write-Information 'Bootstrap completed successfully' -InformationAction Continue