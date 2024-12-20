New-UDPage -Name 'Object Map' -Url '/settings/objectmap' -Content {
    Write-IamAccessLog
    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators') -Children {
        #region Object Map Rules Form
        New-UDCard -Title 'Add Object Map' -Variant outlined -Content {
            New-UDStack -Direction row -Spacing 2 -FullWidth -Children {
                New-UDSelect -Label 'Type' -Id 'Type' -Option {
                    New-UDSelectOption -Name 'OU Path' -Value 'Path'
                    New-UDSelectOption -Name 'Group Membership' -Value 'Group'
                } -OnChange {
                    Sync-UDElement -Id 'dynComparator'
                }

                New-UDSelect -Label 'User Attribute' -Id 'Attribute' -Option {
                    New-UDSelectOption -Name 'Name' -Value 'Name'
                    New-UDSelectOption -Name 'Description' -Value 'Description'
                    New-UDSelectOption -Name 'Email' -Value 'Email'
                    New-UDSelectOption -Name 'Phone' -Value 'Phone'
                    New-UDSelectOption -Name 'Mobile' -Value 'Mobile'
                    New-UDSelectOption -Name 'Title' -Value 'Title'
                    New-UDSelectOption -Name 'Department' -Value 'Department'
                    New-UDSelectOption -Name 'Manager' -Value 'Manager'
                    New-UDSelectOption -Name 'Office' -Value 'Office'
                    New-UDSelectOption -Name 'Street' -Value 'Street'
                    New-UDSelectOption -Name 'City' -Value 'City'
                    New-UDSelectOption -Name 'State' -Value 'State'
                    New-UDSelectOption -Name 'Zip' -Value 'Zip'
                    New-UDSelectOption -Name 'Country' -Value 'Country'
                    New-UDSelectOption -Name 'OU' -Value 'OU'
                }

                New-UDSelect -Label 'Operator' -Id 'Operator' -Option {
                    New-UDSelectOption -Name 'Equals' -Value 'Equals'
                    New-UDSelectOption -Name 'Contains' -Value 'Contains'
                    New-UDSelectOption -Name 'Starts With' -Value 'StartsWith'
                    New-UDSelectOption -Name 'Ends With' -Value 'EndsWith'
                }

                New-UDTextbox -Label 'Comparison Value' -Id 'Value'

                New-UDDynamic -Id 'dynComparator' -Content {
                    $Type = (Get-UDElement -Id 'Type').value
                    if ($Type -eq 'Path') {
                        New-UDTextbox -Label 'Path (OU Distinguished Name)' -Id 'Path' -FullWidth
                    }
                    elseif ($Type -eq 'Group') {
                        New-UDAutocomplete -Label 'Group Name' -Id 'Group' -Options {
                            Get-IamGroupCache | Select-Object -ExpandProperty SamAccountName | Sort-Object
                        } -Multiple -FullWidth
                    }
                    else {
                        New-UDTextbox -Disabled -FullWidth -Label 'Path (OU Distinguished Name)'
                    }
                }

                New-UDButton -Icon (New-UDIcon -Icon plus) -Size small -OnClick {
                    # Construct the rule object
                    $Rule = @{
                        Id        = (New-Guid).ToString()
                        Order     = 1
                        Type      = (Get-UDElement -Id 'Type').value
                        Attribute = (Get-UDElement -Id 'Attribute').value
                        Operator  = (Get-UDElement -Id 'Operator').value
                        Value     = (Get-UDElement -Id 'Value').value
                        Target    = $null
                    }

                    if ((Get-UDElement -Id 'Type').value -eq 'Path') {
                        $Rule.Target = (Get-UDElement -Id 'Path').value
                    }
                    else {
                        $Rule.Target = (Get-UDElement -Id 'Group').value
                    }

                    # Add the rule to the list
                    $CurrentMap = Get-PSFConfigValue -FullName 'PowerIAM.AD.ObjectMap'
                    $List = [System.Collections.Generic.List[object]]@()

                    if ($CurrentMap -and $CurrentMap -isnot [array]) {
                        $null = $List.Add($CurrentMap)
                    }
                    elseif ($CurrentMap -and $CurrentMap -is [array]) {
                        $null = $List.AddRange($CurrentMap)
                    }

                    $Rule.Order = $List.Count + 1
                    $null = $List.Add($Rule)
                    Save-IamConfig -Name AD.ObjectMap -Value $List

                    # Clear the form
                    @('Type', 'Attribute', 'Operator', 'Value', 'Path', 'Group') | ForEach-Object {
                        Set-UDElement -Id $_ -Properties @{ Value = '' }
                    }
                    Sync-UDElement -Id 'dynTable' -Broadcast
                }
            }
        }
        #endregion

        #region Object Map Rules Table
        # Save-IamConfig -Name AD.ObjectMap -Value @()
        # New-UDButton -Text 'Show Object Map' -OnClick {
        #     Show-UDObject (Get-PSFConfigValue -FullName 'PowerIAM.AD.ObjectMap')
        #     #Sync-UDElement -Id 'dynTable'
        # }
        New-UDDynamic -Id 'dynTable' -Content {
            $Map = Get-PSFConfigValue -FullName 'PowerIAM.AD.ObjectMap' | Sort-Object Order

            if ($null -eq $Map) {
                New-UDTypography -Text 'No Object Map rules have been defined.' -Variant h6
                return
            }

            $Columns = @(
                New-UDTableColumn -Property 'Order' -Title 'Order' -Hidden
                New-UDTableColumn -Property 'Id' -Title 'Id' -Hidden
                New-UDTableColumn -Property 'Type' -Title 'Type'
                New-UDTableColumn -Property 'Attribute' -Title 'Attribute'
                New-UDTableColumn -Property 'Operator' -Title 'Operator'
                New-UDTableColumn -Property 'Value' -Title 'Value'
                New-UDTableColumn -Property 'Target' -Title 'Target' -Render {
                    if ($EventData.Target -is [array] -or $EventData.Target -is [System.Collections.ArrayList]) {
                        $EventData.Target -join ', '
                    }
                    else {
                        $EventData.Target
                    }
                }
                New-UDTableColumn -Property 'Actions' -Title 'Actions' -Render {
                    New-UDButton -Icon (New-UDIcon -Icon trash) -Size small -OnClick {
                        $CurrentMap = Get-PSFConfigValue -FullName 'PowerIAM.AD.ObjectMap'
                        $CurrentMap = $CurrentMap | Where-Object { $_.Id -ne $EventData.Id }
                        $CurrentMap = $CurrentMap | ForEach-Object {
                            if ($_.Order -gt $EventData.Order) {
                                $_.Order = $_.Order - 1
                            }
                            $_
                        }
                        Save-IamConfig -Name AD.ObjectMap -Value $CurrentMap
                        Sync-UDElement -Id 'dynTable'
                    }
                }
            )

            New-UDTable -Title 'Object Map Rules' -Data $Map -Columns $Columns
        }
        #endregion
    }
}
