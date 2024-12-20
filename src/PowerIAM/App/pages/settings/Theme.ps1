New-UDPage -Name 'Theme Selector' -Url '/settings/theme' -Content {
    New-UDSelect -Label 'Theme' -Option {
        Get-UDTheme | Sort-Object | ForEach-Object {
            New-UDSelectOption -Name $_ -Value $_
        }
    } -OnChange {
        Set-UDTheme -Name $EventData
    }
}