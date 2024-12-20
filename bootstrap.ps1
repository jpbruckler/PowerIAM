$InformationPreference = 'Continue'
$WarningPreference = 'SilentlyContinue'

#region Function - Write-Console
function Write-Console {
    [CmdletBinding()]
    param(
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Message,

        [Parameter(Position = 2)]
        [ValidateSet('info', 'warn', 'error', 'debug', 'verbose')]
        [string]$Level = 'info',
        [switch]$Success,
        [switch]$StartTask,
        [switch]$EndTask,
        [switch]$ResetIndent
    )

    if (-not (Test-Path Variable:Script:IndentLevel) -or $ResetIndent -or ($Script:IndentLevel -lt 0)) {
        $Script:IndentLevel = 0
    }
    # Adjust indentation level if ending a task
    if ($EndTask) {
        $Script:IndentLevel = $Script:IndentLevel - 1
        if ($Script:IndentLevel -lt 0) {
            $Script:IndentLevel = 0
        }
    }
    $currentIndent = ' ' * ($Script:IndentLevel * 4)



    # ANSI color codes
    # Using bright variants for visibility. Adjust as needed.
    $ansiReset = "`e[0m"
    $colorMap = @{
        'info'    = "`e[97m"   # Bright White
        'warn'    = "`e[33m"   # Yellow
        'error'   = "`e[31m"   # Red
        'debug'   = "`e[35m"   # Magenta
        'verbose' = "`e[36m"   # Cyan
        'success' = "`e[32m"   # Green
    }

    # Determine symbol based on level and indentation
    $symbol = ''
    if ($Script:IndentLevel -gt 0) {
        switch -Wildcard ($Level) {
            'info' {
                if ($Success) {
                    $symbol = '[+]'
                }
                else {
                    $symbol = '-'
                }
            }
            'warn' { $symbol = '[!]' }
            'error' { $symbol = '[x]' }
            'debug' { $symbol = '(*)' }
            'verbose' { $symbol = '(?)' }
        }
    }

    # Determine color
    $useColor = $colorMap[$Level]
    # If success and level=info, override color
    if ($Success -and $Level -eq 'info') {
        $useColor = $colorMap['success']
    }

    # If top-level and no indentation, no symbol should be shown
    $formattedMessage = if ($Script:IndentLevel -gt 0) {
        if ($Success -and $Level -eq 'info') {
            '{0}{1}{2}{3} {4}' -f $currentIndent, $useColor, $symbol, $ansiReset, $Message
        }
        else {
            '{0}{1}{2} {3}{4}' -f $currentIndent, $useColor, $symbol, $Message, $ansiReset
        }
    }
    else {
        '{0}{1}{2}{3}' -f $currentIndent, $useColor, $Message, $ansiReset
    }

    Write-Host $formattedMessage

    # Adjust indentation if starting a new task
    if ($StartTask) {
        $Script:IndentLevel = $Script:IndentLevel + 1
    }
}

function Add-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host 'Scoop not found in PATH. Installing...'
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    }
    else {
        Write-Host 'Scoop found in PATH. Updating Scoop...'
        scoop update
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Console 'Failed to install Scoop!' -Level error
        return $false
    }

    return $true
}
#endregion

Write-Console 'Starting bootstrap process...' -Level info -ResetIndent -StartTask
Write-Console 'Verifying NuGet provider is installed...' -Level info
try {
    # https://docs.microsoft.com/powershell/module/packagemanagement/get-packageprovider
    Get-PackageProvider -Name Nuget -ForceBootstrap -ErrorAction Stop| Out-Null
    Write-Console 'NuGet provider installed successfully' -Level info -Success
}
catch {
    Write-Console 'Failed to install NuGet provider. Exiting.' -Level error
    exit 1
}

try {
    # https://docs.microsoft.com/powershell/module/powershellget/set-psrepository
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Write-Console 'PSGallery repository set to Trusted' -Level info -Success
}
catch {
    Write-Console 'Failed to set PSGallery repository to Trusted' -Level warn
}

# List of PowerShell Modules required for the build
$modulesToInstall = New-Object System.Collections.Generic.List[object]
$modulesToInstall = @(
    @{
        ModuleName    = 'Pester'
        ModuleVersion = '5.6.1'
    },
    @{
        ModuleName    = 'InvokeBuild'
        ModuleVersion = '5.11.3'
    },
    @{
        ModuleName    = 'PSScriptAnalyzer'
        ModuleVersion = '1.22.0'
    },
    @{
        ModuleName    = 'platyPS'
        ModuleVersion = '0.12.0'
    },
    @{
        ModuleName    = 'PsdKit'
        ModuleVersion = '0.6.3'
    },
    @{
        ModuleName    = 'PSHTML'
        ModuleVersion = '0.8.2'
    },
    @{
        ModuleName    = 'PSFramework'
        ModuleVersion = '1.12.346'
    },
    @{
        ModuleName    = 'Microsoft.PowerShell.SecretManagement'
        ModuleVersion = '1.1.2'
    },
    @{
        ModuleName    = 'Microsoft.PowerShell.SecretStore'
        ModuleVersion = '1.0.6'
    }
)


Write-Console 'Installing required PowerShell modules...' -Level info -ResetIndent -StartTask
foreach ($module in $modulesToInstall) {
    $moduleCheck = Get-Module -Name $module.ModuleName -ListAvailable -ErrorAction SilentlyContinue | Select-Object Version | Sort-Object
    if ($moduleCheck -and $moduleCheck.Version -ge [version]$module.ModuleVersion) {
        Write-Console ('{0} version {1} is already installed' -f $module.ModuleName, $module.ModuleVersion) -Level info -Success
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
        Write-Console ('Successfully installed {0} version {1}' -f $module.ModuleName, $module.ModuleVersion) -Level info -Success
    }
    catch {
        Write-Console ('Failed to install {0} version {1}' -f $module.ModuleName, $module.ModuleVersion) -Level error
    }
}

Write-Console 'Installing Python3, pip, and mkdocs. You will be prompted for admin consent...' -Level info -ResetIndent -StartTask

try {
    Write-Console 'Installing Microsoft Build tools, needed to compile pip packages.' -Level info
    $uri = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    $outFile = (Join-Path $env:TEMP 'vs_BuildTools.exe')
    Invoke-WebRequest -Uri $uri -OutFile $outFile -UseBasicParsing
    $result = Start-Process $outFile -ArgumentList '--add Microsoft.VisualStudio.Workload.MSBuildTools --includeRecommended --add Microsoft.VisualStudio.Workload.VCTools --passive --nocache --installWhileDownloading' -Wait -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install Microsoft Build tools'
    }
    Write-Console 'Successfully installed Microsoft Build tools' -Success

    Write-Console 'Installing Python3 via winget.' -Level info
    $result = Start-Process winget -ArgumentList 'install python3 --accept-package-agreements --accept-source-agreements --silent --force' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install Python3'
    }
    Write-Console 'Successfully installed Python3' -Success

    Write-Console 'Installing pip' -Level info
    $result = Start-Process python -ArgumentList '-m pip install --upgrade pip -q -q -q' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install pip'
    }
    Write-Console 'Successfully installed pip' -Success

    Write-Console 'Installing mkdocs and mkdocs-material' -Level info
    $result = Start-Process pip -ArgumentList 'install mkdocs mkdocs-material -q -q -q' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install mkdocs'
    }
    Write-Console 'Successfully installed mkdocs and mkdocs-material' -Success

    Write-Console 'Installing mkdocs requirements' -Level info
    $result = Start-Process pip -ArgumentList 'install -r requirements.txt -q -q -q' -Wait -NoNewWindow -PassThru
    if ($result.ExitCode -ne 0) {
        throw 'Failed to install mkdocs requirements'
    }
    Write-Console 'Successfully installed mkdocs requirements' -Success
}
catch {
    $message = $PSItem.Exception.Message
    Write-Console $message -Level error
    exit 1
}

$null = Add-Scoop
Write-Console 'Checking for git-cliff...' -Level info -ResetIndent -StartTask
if (-not (Get-Command git-cliff -ErrorAction SilentlyContinue)) {
    Write-Console 'git-cliff not found in the path. Attempting to install...' -Level info
    scoop install git-cliff

    if (-not (Get-Command git-cliff -ErrorAction SilentlyContinue)) {
        Write-Console 'Failed to install git-cliff. Please install manually.' -Level error
    }
    else {
        Write-Console 'Successfully installed git-cliff' -Success
    }
}

Write-Console 'Initializing git-cliff configuration...' -Level info
git-cliff --init

if ($LASTEXITCODE -ne 0) {
    Write-Console 'Failed to initialize git-cliff configuration' -Level error -ResetIndent
}
else {
    Write-Console 'Successfully initialized git-cliff configuration' -Success -ResetIndent
}

if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) {
    Write-Console 'infisical not found in the path. Attempting to install using Scoop...' -Level info -StartTask

    if (-not (scoop bucket list | Select-String 'infisical')) {
        Write-Console 'Adding Infisical bucket...'
        scoop bucket add infisical
    }

    Write-Console 'Installing Infisical...' -Level info
    scoop install infisical
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to install Infisical'
    }
    Write-Console 'Successfully installed Infisical' -Success -ResetIndent
}

$OldPester = Get-Module -ListAvailable pester | Where-Object { $_.Version -lt [version]'4.0.0' }
if ($OldPester) {
    Write-Console 'A legacy version of Pester has been found. It is suggested to remove this version.' -Level warn -ResetIndent

    Write-Console @'
To remove, run the following as a user with administrative privileges:

    $module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
    & takeown.exe /F $module /A /R
    & icacls.exe $module /reset
    & icacls.exe $module /grant "*S-1-5-32-544:F" /inheritance:d /T
    Remove-Item -Path $module -Recurse -Force -Confirm:$false
'@ -Level warn -ResetIndent
}

Write-Console 'Bootstrap completed successfully'