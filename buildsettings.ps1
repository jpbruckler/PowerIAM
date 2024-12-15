function Test-ManifestBool ($Path) {
    Get-ChildItem $Path | Test-ModuleManifest -ErrorAction SilentlyContinue | Out-Null; $?
}

function Import-EnvFile {
    $Path = (Join-Path -Path $BuildRoot -ChildPath '.env')

    if (-not (Test-Path $Path -PathType Leaf)) { throw '.env file not found in project root!' }

    $env = Get-Content $Path -Raw | ConvertFrom-StringData
    $pattern = '\$\{([^\}]+)\}'
    $resolvedEnv = @{}
    foreach ($key in $env.Keys) {
        $resolvedEnv[$key] = $env[$key] -replace $pattern, { $env[$_.groups[1].value] }
    }

    $resolvedEnv.GetEnumerator() | ForEach-Object {
        Write-Build Yellow "`tSetting environment variable '$($_.Key)'..."
        [Environment]::SetEnvironmentVariable($_.Key, $_.Value)
    }
}

function Clear-Env {
    if (-not (Test-Path $Path -PathType Leaf)) { throw '.env file not found in project root!' }

    $env = Get-Content $Path -Raw | ConvertFrom-StringData
    $env.Keys | ForEach-Object {
        Write-Build Yellow "`tClearing environment variable '$($_)'..."
        [Environment]::SetEnvironmentVariable($_, $null)
    }
}

function Format-BoxedMessage {
    param(
        [string[]]$Messages
    )

    # Initialize StringBuilder
    $sb = New-Object System.Text.StringBuilder

    $lineWidth = 80  # Total line width
    $indent = '     '  # 5 spaces
    $maxTextWidth = $lineWidth - 2 - $indent.Length - 5  # Adjusted for borders and margins

    # Build the top border line
    $topLine = '╔' + ('═' * ($lineWidth - 2)) + '╗'
    $null = $sb.AppendLine($topLine)

    # Function to wrap text
    function WrapText {
        param(
            [string]$Text,
            [int]$MaxWidth
        )
        $lines = @()
        $currentLine = ''
        foreach ($word in $Text -split '\s+') {
            if (($currentLine.Length + $word.Length + 1) -le $MaxWidth) {
                if ($currentLine.Length -gt 0) {
                    $currentLine += ' '
                }
                $currentLine += $word
            }
            else {
                if ($currentLine.Length -gt 0) {
                    $lines += $currentLine
                }
                $currentLine = $word
            }
        }
        if ($currentLine.Length -gt 0) {
            $lines += $currentLine
        }
        return $lines
    }

    # Process each message
    foreach ($message in $Messages) {
        # Wrap the message text
        $wrappedLines = WrapText -Text $message -MaxWidth $maxTextWidth

        foreach ($line in $wrappedLines) {
            # Build the content line with indentation
            $content = $indent + $line
            # Pad the content to fit within the box
            $content = $content.PadRight($lineWidth - 2)
            $null = $sb.AppendLine("║$content║")
        }
    }

    # Build the bottom border line
    $bottomLine = '╚' + ('═' * ($lineWidth - 2)) + '╝'
    $null = $sb.AppendLine($bottomLine)

    # Output the constructed box
    return $sb.ToString()
}

function Update-ProjectModuleManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Output,

        [Parameter(Mandatory = $true)]
        [hashtable]$Properties
    )
    $export = [ordered] @{}
    $moduleTemplate = [ordered] @{
        RootModule             = $null
        ModuleVersion          = $null
        CompatiblePSEditions   = @()
        GUID                   = $null
        Author                 = $null
        CompanyName            = $null
        Copyright              = $null
        Description            = $null
        PowerShellVersion      = $null
        PowerShellHostName     = $null
        PowerShellHostVersion  = $null
        DotNetFrameworkVersion = $null
        CLRVersion             = $null
        ProcessorArchitecture  = $null
        RequiredModules        = @()
        RequiredAssemblies     = @()
        ScriptsToProcess       = @()
        TypesToProcess         = @()
        FormatsToProcess       = @()
        NestedModules          = @()
        FunctionsToExport      = @()
        CmdletsToExport        = @()
        VariablesToExport      = @()
        AliasesToExport        = @()
        DscResourcesToExport   = @()
        ModuleList             = @()
        FileList               = @()
        PrivateData            = @{
            PSData = @{
                Tags         = @()
                LicenseUri   = $null
                ProjectUri   = $null
                IconUri      = $null
                ReleaseNotes = $null
            }
        }
        HelpInfoURI            = $null
        DefaultCommandPrefix   = $null
    }

    # Read the original PSD1 content
    $psd1Content = Get-Content -Path $Path -Raw

    # Remove commented lines
    $cleanedContent = $psd1Content -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }

    # Convert the cleaned content back to a string
    $cleanedContent = $cleanedContent -join "`n"

    # Parse the cleaned content to get the hashtable
    $moduleManifest = Invoke-Expression -Command $cleanedContent

    # Update the module manifest with the new properties
    foreach ($key in $Properties.Keys) {
        $moduleManifest[$key] = $Properties[$key]
    }

    # convert to ordered hashtable
    foreach ($key in $moduleTemplate.Keys) {
        if ($moduleManifest[$key]) {
            $export[$key] = $moduleManifest[$key]
        }
    }

    # Convert back to PSD format using PsdKit
    $export | ConvertTo-Psd | Set-Content -Path $Output -Force
}