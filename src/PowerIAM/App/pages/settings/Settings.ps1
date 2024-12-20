New-UDPage -Url '/settings' -Name 'Settings' -Content {
    Write-IamAccessLog
    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators') -Children {

        New-UDTabs -Id 'tabSettings' -Centered -Tabs {

            # ------------------------------------------------------------------
            #region Tab: General
            # ------------------------------------------------------------------
            New-UDTab -Id 'tabGeneral' -Icon (New-UDIcon -Icon 'gear') -Text 'General' -Content {
                New-UDTypography -Text 'General Settings' -Variant h4
                New-UDCard -Content {
                    New-UDStack -Children {
                        New-UDStack -Id 'LeftColumn-Inner-Left' -Children {
                            New-UDTextbox -Id 'txtEmailDomain' -Label 'Email Domain' -Value $EventData.Context.EmailDomain
                            New-UDTextbox -Id 'txtDefaultPassword' -Label 'Default Password' -Value $EventData.Context.DefaultPassword
                            New-UDTextbox -Id 'txtDefaultPasswordLength' -Label 'Default Password Length' -Value $EventData.Context.DefaultPasswordLength
                            New-UDTextbox -Id 'txtDefaultPasswordComplexity' -Label 'Default Password Complexity' -Value $EventData.Context.DefaultPasswordComplexity
                        } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth

                        New-UDStack -Id 'LeftColumn-Inner-Right' -Children {
                            New-UDTextbox -Id 'txtDefaultPasswordComplexity' -Label 'Default Password Complexity' -Value $EventData.Context.DefaultPasswordComplexity
                            New-UDTextbox -Id 'txtDefaultPasswordComplexity' -Label 'Default Password Complexity' -Value $EventData.Context.DefaultPasswordComplexity
                            New-UDTextbox -Id 'txtDefaultPasswordComplexity' -Label 'Default Password Complexity' -Value $EventData.Context.DefaultPasswordComplexity
                            New-UDTextbox -Id 'txtDefaultPasswordComplexity' -Label 'Default Password Complexity' -Value $EventData.Context.DefaultPasswordComplexity
                        } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                    } -Spacing 2 -FullWidth -Direction row -JustifyContent space-between
                }
            }
            #endregion Tab: General

            # ------------------------------------------------------------------
            #region Tab: User OUs
            # ------------------------------------------------------------------
            New-UDTab -Text 'User OUs' -Icon (New-UDIcon -Icon 'sitemap') -Content {
                $Current = Get-PSFConfigValue -FullName 'PowerIAM.AD.DptData.UserOUs'
                if ($null -eq $Current) {
                    $Current = @()
                }
                New-UDCard -Title 'Add OU DptData' -Variant outlined -Content {
                    New-UDStack -Direction row -Spacing 2 -FullWidth -Children {
                        New-UDTextbox -Label 'OU Name' -Id 'OUName'
                        New-UDTextbox -Label 'OU Path' -Id 'OUPath'
                        New-UDButton -Icon (New-UDIcon -Icon plus) -Size small -OnClick {
                            $OUPath = (Get-UDElement -Id 'OUPath').Value
                            $OUName = (Get-UDElement -Id 'OUName').Value
                            if ($OUPath -ne '') {
                                $Obj = @{
                                    OUName = $OUName
                                    OUPath = $OUPath
                                }
                                $Current += $Obj
                                Save-IamConfig -Name 'AD.DptData.UserOUs' -Value $Obj -Append
                                Sync-UDElement -Id 'table'
                            }
                            Set-UDElement -Id 'OUName' -Attributes @{ Value = '' }
                            Set-UDElement -Id 'OUPath' -Attributes @{ Value = '' }
                        }
                    }
                }
                New-UDDynamic -Id 'table' -Content {
                    $DataOUs = Get-PSFConfigValue -FullName 'PowerIAM.AD.DptData.UserOUs'
                    New-UDTable -Data $DataOUs -Columns @(
                        New-UDTableColumn -Property OUName -Title 'OU Name'
                        New-UDTableColumn -Property OUPath -Title 'OU Path'
                        New-UDTableColumn -Property Actions -Title 'Actions' -Render {
                            New-UDButton -Icon (New-UDIcon -Icon trash) -OnClick {
                                $DataOUs = $DataOUs | Where-Object { $_.OUPath -ne $EventData.OUPath }
                                Save-IamConfig -Name 'AD.DptData.UserOUs' -Value $DataOUs
                                Sync-UDElement -Id 'table'
                            }
                        }
                    )
                }
            }
            #endregion Tab: User OUs

            # ------------------------------------------------------------------
            #region Tab: Department Names
            # ------------------------------------------------------------------
            New-UDTab -Text 'Departments' -Icon (New-UDIcon -Icon 'building-user') -Content {
                $DptData = Get-PSFConfigValue -FullName 'PowerIAM.Data.Departments'
                if ($null -eq $DptData -or $DptData -isnot [array]) {
                    $DptData = @()
                }

                $dptCardHeader = New-UDCardHeader -Title 'Add Department and Titles'
                $dptCardBody = New-UDCardBody -Content {
                    New-UDStack -Children {
                        New-UDTextbox -Label 'Department Name' -Id 'txtDepartmentName'
                        New-UDAutocomplete -OnLoadOptions {
                            $return = (Get-PSFConfigValue -FullName 'PowerIAM.Data.Departments').Titles | Where-Object { $_ -match $Body } | ConvertTo-Json
                            if ($null -eq $return) {
                                $Body | ConvertTo-Json
                            }
                            else {
                                $return
                            }
                        } -Id 'acTitles' -Multiple -Label 'Titles'
                    } -Spacing 2 -Direction row
                }

                $dptCardFooter = New-UDCardFooter -Content {
                    New-UDButton -Text 'Save' -OnClick {
                        # Show-UDToast -Message 'Saving Department Data' -Duration 3000
                        $Titles = (Get-UDElement -Id 'acTitles').Value
                        $DepartmentName = (Get-UDElement -Id 'txtDepartmentName').Value

                        if ($DepartmentName -in $DptData.DepartmentName) {
                            New-UDError -Message "Department '$DepartmentName' already exists"
                            return
                        }
                        else {
                            $Dpt = @{
                                DepartmentName = $DepartmentName
                                Titles         = $Titles
                            }
                            Save-IamConfig -Name 'Data.Departments' -Value $Dpt -Append -AsArray
                            Sync-UDElement -Id 'dynTableDepartment'
                            Set-UDElement -Id 'txtDepartmentName' -Properties @{ Value = '' }
                            Set-UDElement -Id 'acTitles' -Properties @{ Value = '' }
                        }
                    } -Disabled:$(if ($null -eq (Get-UDElement -Id 'acTitles').Value) { $true } else { $false })
                }
                New-UDErrorBoundary {
                    New-UDCard -Header $dptCardHeader -Body $dptCardBody -Footer $dptCardFooter
                }

                New-UDDynamic -Id 'dynTableDepartment' -Content {
                    $TableData = Get-PSFConfigValue -FullName 'PowerIAM.Data.Departments'
                    New-UDTable -Data $TableData -Columns @(
                        New-UDTableColumn -Property DepartmentName -Title 'Department Name'
                        New-UDTableColumn -Property Titles -Title 'Titles' -OnRender {
                            $EventData.Titles -join ', '
                        }
                    )
                }
            }
            #endregion Tab: Department Names
        }
    }
}
