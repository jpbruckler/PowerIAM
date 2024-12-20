New-UDPage -Url '/settings/email' -Name 'Email' -Content {
    Write-IamAccessLog
    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators') -Children {
        New-UDDynamic -Id 'dynForm' -Content {
            $EmailCfg = Get-PSFConfig -Module PowerIAM | Where-Object Name -Like 'Email.*'

            $page:EmailSettings = @{}
            $EmailCfg | ForEach-Object {
                $page:EmailSettings.($_.Name) = @{
                    Name        = $_.Name
                    Value       = $_.Value
                    Description = $_.Description
                    Type        = $_.Type
                }
            }

            New-UDForm -Id 'iamEmailSettings' -Children {
                $page:EmailSettings.GetEnumerator() | ForEach-Object {
                    if ($_.Value.Type -eq 'System.Object[]') {
                        New-UDTextbox -Id $_.Value.Name -Label $_.Value.Name -Value ($_.Value.Value -join "`n") -Multiline -Rows 5 -HelperText $_.Value.Description
                    }
                    else {
                        New-UDTextbox -Id $_.Value.Name -Label $_.Value.Name -Value $_.Value.Value -HelperText $_.Value.Description
                    }
                }
            } -OnSubmit {
                foreach ($key in $page:EmailSettings.Keys) {
                    $NewVal = (Get-UDElement -Id $key).Value
                    if ($page:EmailSettings[$key].Type -eq 'System.Object[]') {
                        $NewVal = $NewVal -split "`n|,|;"
                    }

                    Set-PSFConfig -Name $key -Value $NewVal -Module PowerIAM -PassThru | Register-PSFConfig
                }
                Export-IamConfig
                Show-UDToast -Message "Email settings updated." -Duration 3000 -Position topCenter
            }
        }
    }
}