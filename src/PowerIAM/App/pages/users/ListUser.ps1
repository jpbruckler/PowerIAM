New-UDPage -Name 'Users' -Url '/users/list' -Content {
    Write-IamAccessLog
    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators', 'PowerIAM Operators', 'PowerIAM Users') -Children {
        $lwtKey = '{0}.LastWriteTime' -f (Get-PSFConfigValue -FullName PowerIAM.Cache.User.Key)
        New-UDTypography -Text 'Users' -Variant h4 -Style @{ 'margin-bottom' = '1em' }

        New-UDElement -Tag 'div' -Content {
            New-UDTypography -Text ('Last user cache update: {0}' -f (Get-PSUCache -Key $lwtKey)) -Variant caption
        } -Attributes @{ style = @{ 'margin-bottom' = '1em' } }

        # ----------------------------------------------
        # New user button
        # ----------------------------------------------
        New-UDFloatingActionButton -Icon (New-UDIcon -Icon 'user-plus') -OnClick {
            Show-UDToast -Message 'Hello'
        } -Id 'fab1' -Position BottomRight -Size small

        # ----------------------------------------------
        # Gather data and generate table
        # ----------------------------------------------
        $CacheKey = (Get-PSFConfigValue -FullName 'PowerIAM.Cache.User.Key')
        $Data = Get-PSUCache -Key $CacheKey
        if ($null -eq $Data) {
            Show-UDToast -Message "Cache is empty. Refreshing cache at key $CacheKey" -Duration 5000 -Position topRight
            Checkpoint-IamCache -Scope User -Force
            $Data = Get-PSUCache -Key $CacheKey
        }

        $DataGridParams = @{
            AutoHeight         = $true
            AutoSizeColumns    = $true
            ColumnBuffer       = 5
            DefaultSortColumn  = 'samAccountName'
            HeaderFilters      = $true
            IdentityColumn     = 'samAccountName'
            PageSize           = 50
            RowsPerPageOptions = @(10, 25, 50, 100)
            ShowPagination     = $true
            ShowQuickFilter    = $true
            StripedRows        = $true
            Columns            = @(
                New-UDDataGridColumn -Field samAccountName      -HeaderName 'Username'      -Filterable -Sortable -Render {
                    if ($EventData.Enabled) {
                        $severity = 'success'
                    }
                    else {
                        $severity = 'error'
                    }

                    if ($EventData.lockedOut) {
                        $severity = 'warning'
                    }
                    New-UDAlert -Text $EventData.samAccountName -Severity $severity -Dense
                } -Resizable -Flex 2
                New-UDDataGridColumn -Field displayName         -HeaderName 'Display Name'  -Filterable -Sortable -Flex 2
                New-UDDataGridColumn -Field userPrincipalName   -HeaderName 'UPN'           -Filterable -Sortable -Flex 3
                New-UDDataGridColumn -Field department          -HeaderName 'Department'    -Filterable -Sortable -Groupable
            )
            LoadRows           = {
                $Data | Out-UDDataGridData -Context $EventData -TotalRows $Data.Length
            }
        }
        New-UDElement -Tag 'div' -Content {
            New-UDDataGrid @DataGridParams -LoadDetailContent {
                $Text = 'User Details - {0}' -f $EventData.row.DistinguishedName
                $colSpacing = 2
                New-UDAlert -Text $Text -Severity info
                $profileImage = if ([string]::IsNullOrWhiteSpace($RowData.ThumbnailPhoto)) {
                    @{ Path = Join-Path (Get-PSFConfigValue -FullName PowerIAM.AppFolder) -ChildPath 'Assets\Default_pfp.jpg' }

                }
                else {
                    @{ Url = "data:image/jpeg;base64,$([system.convert]::ToBase64String($EventData.row.ThumbnailPhoto))" }
                }

                New-UDGrid -Container -Content {
                    New-UDStack -Content {
                        New-UDElement -Tag div -Attributes @{ style = @{ 'margin-right' = '100px'; 'margin-left' = '2em'; } } -Content {
                            New-UDImage -Id 'ThumbnailPhoto' -Height 100 -Width 100 @profileImage
                        }
                    } -Spacing $colSpacing
                    New-UDStack -Content {
                        New-UDList -Content {
                            New-UDListItem -Label $EventData.row.Title      -SubTitle 'Title'   -Icon (New-UDIcon -Icon 'user')
                            New-UDListItem -Label $EventData.row.Office     -SubTitle 'Office'  -Icon (New-UDIcon -Icon 'building')
                            New-UDListItem -Label $EventData.row.Manager    -SubTitle 'Manager' -Icon (New-UDIcon -Icon 'user-tie')
                        }
                    } -Spacing $colSpacing -AlignItems flex-start
                    New-UDStack -Content {} -Spacing $colSpacing
                    New-UDStack -Content {
                        New-UDList -Content {
                            New-UDListItem -Label $EventData.row.TelephoneNumber    -SubTitle 'Phone'           -Icon (New-UDIcon -Icon 'phone')
                            New-UDListItem -Label $EventData.row.Mobile             -SubTitle 'Mobile'          -Icon (New-UDIcon -Icon 'mobile')
                            New-UDListItem -Label $EventData.row.EmailAddress       -SubTitle 'Email Address'   -Icon (New-UDIcon -Icon 'envelope')
                        }
                    } -Spacing $colSpacing -AlignItems flex-start
                    New-UDStack -Content {
                        New-UDList -Content {
                            New-UDListItem -Label $EventData.row.PasswordLastSet       -SubTitle 'Password Last Set'    -Icon (New-UDIcon -Icon 'key')
                            New-UDListItem -Label $EventData.row.LastLogon             -SubTitle 'Last Logon'           -Icon (New-UDIcon -Icon 'right-to-bracket')
                            New-UDListItem -Label $EventData.row.AccountExpirationDate -SubTitle 'Account Expiration'   -Icon (New-UDIcon -Icon 'calendar-xmark')
                        }
                    } -Spacing $colSpacing -AlignItems flex-start
                    New-UDStack -Content {
                        New-UDList -Content {
                            New-UDListItem -Label $EventData.row.Created  -SubTitle 'Created'  -Icon (New-UDIcon -Icon 'calendar-plus')
                            New-UDListItem -Label $EventData.row.Modified -SubTitle 'Modified' -Icon (New-UDIcon -Icon 'calendar-check')
                        }
                    } -Spacing $colSpacing -AlignItems flex-start
                } -ColumnSpacing $colSpacing -Direction row -Spacing 2

                # New-UDGrid -Container -Content {
                #     New-UDStack -Content {
                #         New-UDImage -Id 'ThumbnailPhoto' -Height 100 -Width 100 @profileImage
                #     } -Spacing 2 -Direction Column
                #     New-UDStack -Content {
                #         New-UDStack -Content {
                #             New-UDElement -Tag 'ul' -Content {
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Title: {0}' -f $EventData.row.Title)
                #                 }
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Office: {0}' -f $EventData.row.Office)
                #                 }
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Manager: {0}' -f $EventData.row.Manager)
                #                 }
                #             }
                #         } -Spacing 2 -Direction Column
                #         New-UDStack -Content {
                #             New-UDElement -Tag 'ul' -Content {
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Phone:{0}' -f $EventData.row.TelephoneNumber)
                #                 }
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Mobile:{0}' -f $EventData.row.Mobile)
                #                 }
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Email:{0}' -f $EventData.row.EmailAddress)
                #                 }
                #             }
                #         } -Spacing 2 -Direction column
                #         New-UDStack -Content {
                #             New-UDElement -Tag 'ul' -Content {
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Password Last Set: {0}' -f $EventData.row.PasswordLastSet)
                #                 }
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Last Logon: {0}' -f $EventData.row.LastLogon)
                #                 }
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Account Expiration: {0}' -f $EventData.row.AccountExpirationDate)
                #                 }
                #             }
                #         } -Spacing 2 -Direction Column
                #         New-UDStack -Content {
                #             New-UDElement -Tag 'ul' -Content {
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Created: {0}' -f $EventData.row.Created)
                #                 }
                #                 New-UDElement -Tag 'li' -Content {
                #                     New-UDTypography -Text ('Modified: {0}' -f $EventData.row.Modified)
                #                 }
                #             }
                #         } -Spacing 2 -Direction Column
                #     } -Direction Row
                # }
            }
        } -Attributes @{ style = @{ 'margin-right' = '60px'; 'margin-left' = '1.5em' } }
    }
}