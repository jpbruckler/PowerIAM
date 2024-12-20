New-UDPage -Url '/settings/filepickup' -Name 'File Pickup' -Content {
    Write-IamAccessLog
    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators') -Children {
        $Data = @()
        $moduleSettings = Get-PSFConfig -Module PowerIAM | Where-Object Name -Match 'FilePickup'
        $moduleSettings | ForEach-Object {
            $Row = [PSCustomObject]@{
                Setting     = $_.Name
                Value       = if ($_.Value | Assert-IsScalar) { $_.Value } else { $_.Value -join ', ' }
                Description = $_.Description
            }
            $Data += $Row
        }

        New-UDDynamic -Id 'table' -Content {
            New-UDTable -Data $Data -Columns @(
                New-UDTableColumn -Property ObjectGUID -Title 'Edit' -Render {
                    New-UDButton -Icon (New-UDIcon -Icon Edit) -OnClick {
                        $Item = $EventData
                        Show-UDModal -Content {
                            New-UDForm -Children {
                                New-UDTextbox -Id SettingName -Value $Item.Setting -Disabled
                                New-UDTextbox -Id SettingValue -Value $Item.Value
                            } -SubmitText 'Update Setting' -Id "form$($Item.Setting)" -OnSubmit {
                                if ((Get-PSFConfigValue -FullName "PowerIAM.$($EventData.SettingName)") -is [array] ) {
                                    $newValue = $EventData.SettingValue.split(',')
                                }
                                else {
                                    $newValue = $EventData.SettingValue
                                }
                                Save-Iamconfig -Name $Item.Setting -Value $newValue
                                Sync-UDElement -Id 'table'
                                Sync-UDElement -Id 'dynOps'
                                Hide-UDModal
                            } -OnCancel {
                                Hide-UDModal
                            }
                        }
                    }
                }
                New-UDTableColumn -Property Setting -Title 'Name'
                New-UDTableColumn -Property Value -Title 'Value'
                New-UDTableColumn -Property Description -Title 'Description'
            ) -Title 'File Pickup Settings'
        }

        New-UDDynamic -Id 'dynOps' -Content {
            New-UDErrorBoundary -Content {
                $WatchDirectory = Get-PSFConfigValue -FullName PowerIAM.FilePickup.Path
                [bool]$DirExists = Test-Path -Path $WatchDirectory -PathType Container

                $Body = New-UDCardBody -Content {
                    New-UDTable -Data @(
                        [PSCustomObject]@{
                            Name  = 'Watch Directory'
                            Value = $WatchDirectory
                        }
                    ) -Columns @(
                        New-UDTableColumn -Property Name -Render {
                            $path = $EventData.Value
                            if ($null -ne $path -and (Test-Path -Path $path -PathType Container)) {
                                $icon = New-UDIcon -Icon circle-check -Color green
                            }
                            else {
                                $icon = New-UDIcon -Icon circle-exclamation -Color red
                            }
                            $icon
                        } -Width 50 -Title 'Exists'
                        New-UDTableColumn -Property Value -Title 'Directory Path'
                    )
                }

                $Footer = New-UDCardFooter -Content {
                    New-UDButton -Text 'Create Pickup Path' -OnClick {
                        New-Item -Path $WatchDirectory -ItemType Directory
                        Sync-UDElement -Id 'dynOps'
                    } -Disabled:$DirExists

                    New-UDButton -Text 'Test Path' -OnClick {
                        Show-UDObject (Test-Path -Path $WatchDirectory -PathType Container)
                    }
                }

                New-UDCard -Body $Body -Footer $Footer
            }
        }
    }
}