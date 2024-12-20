New-UDPage -Name 'Onboard User' -Url '/users/onboard' -Title 'Onboard User' -Content {
    Write-IamAccessLog

    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators', 'PowerIAM Operators') -Children {
        # Define which workers to run once the form is submitted and validated.
        $WORKERS = @('OnboardUser', 'AddGroupMemberships', 'SetProxyAddresses')

        #region Variable Setup
        $StackSpacing = 3
        $DefaultEmailDomain = Get-PSFConfigValue -FullName PowerIAM.AD.EmailDomain
        $UserData = Get-IamUserCache
        $GroupData = Get-IamGroupCache
        $FailedIcon = New-UDIcon -Icon exclamation -Color '#9b2226'
        $MandatoryIcon = New-UDIcon -Icon 'asterisk' -Color '#780000'
        $session:AccountProperties = @{
            RequestType       = 'OnboardUserForm'
            TicketNumber      = $null
            RequestedBy       = $User
            UserType          = $null
            PreferredName     = $null
            GroupMemberships  = $null
            Name              = $null
            GivenName         = $null
            Surname           = $null
            DisplayName       = $null
            EmployeeID        = $null
            SamAccountName    = $null
            UserPrincipalName = $null
            EmailAddress      = $null
            Office            = $null
            OfficePhone       = $null
            MobilePhone       = $null
            Manager           = $null
            Department        = $null
            Title             = $null
            HireDate          = $null
            HireTime          = $null
            Path              = $null
        }
        $page:TitleOptions = $null
        $session:ValidationResults = $null

        # # Create arrays of items for auto-populating fields
        $ti = (Get-Culture).TextInfo

        $Groups = $GroupData |
            Select-Object -ExpandProperty SamAccountName | Sort-Object | ForEach-Object {
                $ti.ToTitleCase($_)
            } | Select-Object -Unique

        $Departments = $UserData |
            Select-Object -ExpandProperty Department | Sort-Object | ForEach-Object {
                $ti.ToTitleCase($_)
            } | Select-Object -Unique

        $Managers = $userData |
            Where-Object DirectReports -NE $null |
            Select-Object @{ n = 'Option'; e = { '{0} - {1}' -f $_.DisplayName, $_.SamAccountName } } |
            Select-Object -ExpandProperty Option

        $Offices = $UserData |
            Select-Object @{n = 'TitleCase'; e = { $ti.ToTitleCase($_.Office) } } -Unique |
            Sort-Object TitleCase |
            Select-Object -ExpandProperty TitleCase

        $Titles = @{}
        $Departments | ForEach-Object {
            $Titles[$_] = $UserData | Where-Object Department -EQ $_ | Select-Object -ExpandProperty Title -Unique | Sort-Object
        }
        #endregion

        #region Validation Message Display
        New-UDDynamic -Id 'dynValMsg' -Content {
            $FailedTests = $session:ValidationResults.Failed
            if ($FailedTests) {
                New-UDPaper -Children {
                    New-UDList -Content {
                        foreach ($fail in $FailedTests) {
                            New-UDListItem -Label $fail.TestTitle -Icon $FailedIcon -Style @{ color = 'red' }
                        }
                    } -Dense
                }
            }
        }
        #endregion

        #region UserForm
        New-UDForm -Id 'OnboardUser' -Children {

            # begin layout grid
            New-UDGrid -Container -Children {
                # begin left column layout
                New-UDGrid -Item -Direction column -ExtraSmallSize 6 -Content {
                    New-UDTypography -Text 'Account Information' -Variant h4
                    # TODO: Add selector for elevated account
                    New-UDCard -Content {
                        New-UDStack -Children {
                            New-UDStack -Id 'LeftColumn-Inner-Left' -Children {
                                New-UDTextbox -Id 'GivenName' -Label 'First Name' -Icon $MandatoryIcon -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                                New-UDTextbox -Id 'Surname' -Label 'Last Name' -Icon $MandatoryIcon   -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                                New-UDTextbox -Id 'EmployeeID' -Label 'Employee ID' -Icon $MandatoryIcon  -MaximumLength 6 -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth

                            New-UDStack -Id 'LeftColumn-Inner-Right' -Children {
                                New-UDTextbox -Id 'OfficePhone' -Label 'Office Phone' -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                                New-UDTextbox -Id 'MobilePhone' -Label 'Mobile Phone' -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                                New-UDSelect -Id 'UserType' -Label 'Account Type' -Option {
                                    New-UDSelectOption -Name 'Employee'     -Value 'User'
                                    New-UDSelectOption -Name 'Contractor'   -Value 'Contractor'
                                    New-UDSelectOption -Name 'Vendor'       -Value 'Vendor'
                                } -OnChange {
                                    Sync-UDElement -Id 'dynAccountInfo'
                                } -DefaultValue 'User'
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                        } -Spacing 2 -FullWidth -Direction row -JustifyContent space-between

                        New-UDStack -Children {
                            New-UDHtml -Markup '<br />'
                            New-UDHtml -Markup '<br />'
                            New-UDTextbox -Id 'TicketNumber' -Label 'Ticket Number' -Icon $MandatoryIcon -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                        } -Direction column -JustifyContent space-between -FullWidth
                    }
                    # end Account Information

                    New-UDHtml -Markup '<br />'
                    New-UDTypography -Text 'Position Information' -Variant h4
                    New-UDCard -Content {
                        New-UDStack -Children {
                            New-UDStack -Children {
                                New-UDAutocomplete -Id 'Department' -Label 'Department' -Options $Departments -OnChange {
                                    $session:AccountProperties['Department'] = $EventData
                                    $page:TitleOptions = $Titles[$EventData]
                                    Sync-UDElement -Id 'dynTitles'
                                    Sync-UDElement -Id 'dynAccountInfo'
                                } -FullWidth -Icon $MandatoryIcon

                                New-UDDynamic -Id 'dynTitles' -Content {
                                    New-UDSelect -Id 'Title' -Label 'Title/Job Description' -Option {
                                        if (-not ([string]::IsNullOrEmpty($page:TitleOptions))) {
                                            $page:TitleOptions | ForEach-Object {
                                                New-UDSelectOption -Name $_ -Value $_
                                            }
                                        }
                                    } -OnChange {
                                        Sync-UDElement -Id 'dynAccountInfo'
                                    } -FullWidth
                                }
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                            New-UDStack -Children {
                                New-UDAutocomplete -Id 'Manager' -Label 'Manager' -OnLoadOptions {
                                    $Managers | Where-Object { $_ -like "*$Body*" } | ConvertTo-Json
                                } -FullWidth -OnChange {
                                    Sync-UDElement -Id 'dynAccountInfo'
                                } -Icon (New-UDIcon -Icon 'asterisk' -Color '#780000' )
                                New-UDAutocomplete -Id 'Office' -Label 'Office' -Options $Offices -FullWidth -OnChange {
                                    Sync-UDElement -Id 'dynAccountInfo'
                                } -Icon (New-UDIcon -Icon 'asterisk' -Color '#780000' )
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                        } -Spacing 2 -FullWidth -Direction row -JustifyContent space-between
                        # end Position Information
                    }

                    New-UDHtml -Markup '<br />'
                    New-UDTypography -Text 'Optional' -Variant h4
                    New-UDCard -Content {
                        New-UDStack -Children {
                            New-UDStack -Children {
                                New-UDTextbox -Id 'PreferredName' -Label 'Preferred Name' -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                            New-UDStack -Children {
                                New-UDAutocomplete -Id 'usrGrps' -Label 'Additional Group Memberships' -Options $Groups -Multiple -FullWidth -OnChange {
                                    Sync-UDElement 'dynAccountInfo'
                                }
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                        } -Spacing 2 -FullWidth -Direction row -JustifyContent space-between
                        New-UDStack -Children {
                            New-UDHtml -Markup '<br />'
                            New-UDHtml -Markup '<br />'
                            New-UDTypography -Text 'Schedule Account Creation' -Variant h4
                            New-UDTypography -Text 'Select the date and time the account should be created. Leave blank to create the account immediately.' -Variant body2
                            New-UDHtml -Markup '<br />'
                        } -Direction column -JustifyContent space-between -FullWidth
                        # TODO: Implement date and time picker after IronmanSoftware support resolves gRPC issue
                        New-UDStack -Children {
                            New-UDStack -Children {
                                New-UDDatePicker -Id 'HireDate' -Label 'Hire Date' -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                            New-UDStack -Children {
                                New-UDTimePicker -Id 'HireTime' -Label 'Hire Time' -OnChange { Sync-UDElement -Id 'dynAccountInfo' }
                            } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                        } -Spacing 2 -FullWidth -Direction row -JustifyContent space-between
                    }
                }
                # end left column layout


                # begin right column layout
                New-UDGrid -Item -Direction column -ExtraSmallSize 6 -Content {
                    New-UDTypography -Text 'Preview' -Variant h4
                    New-UDCard -Content {
                        New-UDDynamic -Id 'dynAccountInfo' -Content {
                            $userType = (Get-UDElement -Id 'UserType').Value
                            $session:AccountProperties['PreferredName'] = (Get-UDElement -Id 'PreferredName').Value
                            $session:AccountProperties['UserType'] = (Get-UDElement -Id 'UserType').Value
                            $session:AccountProperties['GivenName'] = (Get-UDElement -Id 'GivenName').Value
                            $session:AccountProperties['Surname'] = (Get-UDElement -Id 'Surname').Value
                            $session:AccountProperties['EmployeeID'] = (Get-UDElement -Id 'EmployeeID').Value
                            $session:AccountProperties['OfficePhone'] = (Get-UDElement -Id 'OfficePhone').Value
                            $session:AccountProperties['MobilePhone'] = (Get-UDElement -Id 'MobilePhone').Value
                            $session:AccountProperties['Department'] = (Get-UDElement -Id 'Department').Value
                            $session:AccountProperties['Title'] = (Get-UDElement -Id 'Title').Value
                            $session:AccountProperties['Manager'] = (Get-UDElement -Id 'Manager').Value
                            $session:AccountProperties['Office'] = (Get-UDElement -Id 'Office').Value
                            $session:AccountProperties['TicketNumber'] = (Get-UDElement -Id 'TicketNumber').Value
                            $session:AccountProperties['HireDate'] = (Get-UDElement -Id 'HireDate').Value
                            $session:AccountProperties['HireTime'] = (Get-UDElement -Id 'HireTime').Value

                            # Calculate SamAccountName from the user type
                            $samPrefix = switch ($userType) {
                                'User' { 'u' }
                                'Contractor' { 'c' }
                                'Vendor' { 'v' }
                                default { 'u' }
                            }
                            if ([string]::IsNullOrEmpty($session:AccountProperties['EmployeeId'])) {
                                $session:AccountProperties['SamAccountName'] = '{0}00000' -f $samPrefix
                            }
                            else {
                                $session:AccountProperties['SamAccountName'] = '{0}{1}' -f $samPrefix, $session:AccountProperties['EmployeeId'].Substring(1)
                            }
                            $session:AccountProperties['Name'] = $session:AccountProperties['SamAccountName']

                            # Calculate UserPrincipalName
                            $session:AccountProperties['UserPrincipalName'] = if ([string]::IsNullOrEmpty($session:AccountProperties['GivenName'])) {
                                $null
                            }
                            else {
                                ('{0}.{1}@{2}' -f $session:AccountProperties['GivenName'], $session:AccountProperties['Surname'], $DefaultEmailDomain).ToLower() -replace ' ', '.'
                            }

                            # Calculate primary email address
                            if ([string]::IsNullOrEmpty($session:AccountProperties['GivenName']) -AND [string]::IsNullOrEmpty($session:AccountProperties['Surname'])) {
                                $session:AccountProperties['DisplayName'] = $null
                                $session:AccountProperties['EmailAddress'] = $null
                            }
                            elseif ($session:AccountProperties['PreferredName']) {
                                $session:AccountProperties['DisplayName'] = '{0} {1}' -f $session:AccountProperties['PreferredName'], $session:AccountProperties['Surname']
                                $session:AccountProperties['EmailAddress'] = ('{0}.{1}@{2}' -f $session:AccountProperties['PreferredName'], $session:AccountProperties['Surname'], $DefaultEmailDomain).ToLower() -replace ' ', '.'
                            }
                            else {
                                $session:AccountProperties['DisplayName'] = '{0} {1}' -f $session:AccountProperties['GivenName'], $session:AccountProperties['Surname']
                                $session:AccountProperties['EmailAddress'] = ('{0}.{1}@{2}' -f $session:AccountProperties['GivenName'], $session:AccountProperties['Surname'], $DefaultEmailDomain).ToLower() -replace ' ', '.'
                            }

                            # Calculate group memberships
                            $session:AccountProperties['GroupMemberships'] = ((Get-IamMapValue -InputObject $session:AccountProperties -MapType Group) -split ',') | Sort-Object
                            $AddlGroups = (Get-UDElement -Id 'usrGrps').Value
                            if ($AddlGroups) {
                                foreach ($grp in $AddlGroups) {
                                    if ($grp -notin $session:AccountProperties['GroupMemberships']) {
                                        $session:AccountProperties['GroupMemberships'] += $grp
                                    }
                                }
                            }

                            # Calculate Org Unit path
                            $session:AccountProperties['Path'] = Get-IamMapValue -InputObject $session:AccountProperties -MapType Path

                            New-UDStack -Children {
                                New-UDTextbox -Id 'aiDisplayName' -Label 'Display Name' -Disabled -Value $session:AccountProperties['DisplayName']
                                New-UDTextbox -Id 'aiEmail' -Label 'Email' -Disabled -Value $session:AccountProperties['EmailAddress']
                                New-UDTextbox -Id 'aiUserPrincipalName' -Label 'User Principal Name' -Disabled -Value $session:AccountProperties['UserPrincipalName']
                                New-UDTextbox -Id 'aiSamAccountName'    -Label 'Account Name/User ID' -Disabled -Value $session:AccountProperties['SamAccountName']
                                New-UDTextbox -Id 'aiPath' -Label 'Org Unit' -Disabled -Value $session:AccountProperties['Path']
                                New-UDTextbox -Id 'aiOfficePhone' -Label 'Office Phone' -Disabled -Value $session:AccountProperties['OfficePhone']
                                New-UDTextbox -Id 'aiMobilePhone' -Label 'Mobile Phone' -Disabled -Value $session:AccountProperties['MobilePhone']
                                New-UDTextbox -Id 'aiGroups' -Label 'Groups' -Disabled -Value ($session:AccountProperties['GroupMemberships'] -join "`n") -Multiline -Rows 4

                                New-UDHtml -Markup '<hr />'
                                New-UDTextbox -Id 'aiDepartment' -Label 'Department' -Disabled -Value $session:AccountProperties['Department']
                                New-UDTextbox -Id 'aiTitle' -Label 'Title' -Disabled -Value $session:AccountProperties['Title']
                                New-UDTextbox -Id 'aiManager' -Label 'Manager' -Disabled -Value $session:AccountProperties['Manager']
                                New-UDTextbox -Id 'aiOffice' -Label 'Office' -Disabled -Value $session:AccountProperties['Office']

                                if (-not ([string]::IsNullOrWhiteSpace($session:AccountProperties['PreferredName']))) {
                                    # --------------------------------------------------------------
                                    # Reference: https://learn.microsoft.com/en-us/troubleshoot/entra/entra-id/user-prov-sync/proxyaddresses-attribute-populate#terminology
                                    #
                                    # "SMTP" prefix = Primary SMTP address
                                    #   The primary email address of an Exchange recipient object,
                                    #   including the SMTP protocol prefix.
                                    #   For example, SMTP:john.doe@Contoso.com.
                                    #
                                    # "smtp" prefix = Secondary smtp address
                                    #   Additional email address(es) of an Exchangerecipient object.
                                    #   For example, smtp:john.doe@Contoso.com.
                                    #
                                    # At DTM, the primary email address is always the UserPrincipalName
                                    # --------------------------------------------------------------

                                    $primaryEmail = $session:AccountProperties['UserPrincipalName']
                                    $secondaryEmail = $session:AccountProperties['EmailAddress']
                                    $session:AccountProperties['proxyAddresses'] = @()
                                    $session:AccountProperties['proxyAddresses'] += ('smtp:{0}' -f $primaryEmail)
                                    $session:AccountProperties['proxyAddresses'] += ('SMTP:{0}' -f $secondaryEmail)

                                    New-UDTextbox -Multiline -Id 'aiProxyAddresses' -Label 'Email Aliases' -Value ($session:AccountProperties['proxyAddresses'] -join "`n") -Type text -Disabled -Rows 5
                                }
                            } -Direction column -JustifyContent space-between -FullWidth -Spacing $StackSpacing
                        }
                    }
                }
                # end right column layout
            }
            # end layout grid
        } -OnSubmit {
            # Gather entered form data and send off to validation
            $session:ValidationResults = Invoke-IamValidationTest -TestName 'NewUser' -TestData $session:AccountProperties
            $OnboardScript = Get-PSUScript -Name 'PowerIAM\Invoke-IamWorkflow'
            if ($session:ValidationResults.Result -eq 'Failed') {
                Sync-UDElement -Id 'dynValMsg'
                foreach ($failed in $session:ValidationResults.Failed) {
                    Set-UDElement -Id $failed.FieldID -Properties @{ Icon = $FailedIcon }
                }
            }
            else {

                Write-IamLog -Level Information -Message 'New user form validation passed. Sending data to workflow.'
                Write-IamLog -Level Information -Object @{
                    Action      = 'OnboardUserFromForm'
                    InitiatedBy = $User
                    From        = $RemoteIpAddress
                    Headers     = $Headers
                }

                #region Schedule the onboarding job
                # Schedule the account creation if a date is provided
                if ($null -ne $session:AccountProperties['HireDate']) {
                    Write-IamLog -Level Information -Message "Scheduling account creation for $($session:AccountProperties['SamAccountName'])"

                    # If a hire time was given, then use it. Otherwise, default to 5 minutes after midnight.
                    if ($null -ne $session:AccountProperties['HireTime']) {
                        $time = $session:AccountProperties['HireTime'].ToString('HH:mm:ss')
                    }
                    else {
                        $time = '00:05:00'
                    }

                    $date = $session:AccountProperties['HireDate'].ToString('yyyy-MM-dd')
                    $schedDT = (Get-Date ('{0} {1}' -f $date, $time)).ToUniversalTime()

                    $splat = @{
                        OneTime     = $schedDT
                        Script      = $OnboardScript.Name
                        Environment = 'PowerIAM'
                        Credential  = (Get-PSFConfigValue -FullName PowerIAM.Cred.AD.Write)
                        Integrated  = $true
                        Name        = ('OnboardUser - {0}' -f $session:AccountProperties['SamAccountName'])
                        Parameters  = @{
                            InputObject  = $session:AccountProperties
                            Workers      = $WORKERS
                            WorkflowType = 'Onboard'
                        }
                    }

                    #$splat | Show-UDObject
                    $sched = New-PSUSchedule @splat
                    Write-IamLog -Level Information -Message "Onboard of $($session:AccountProperties['SamAccountName']) Scheduled for: $schedDT"
                    Write-IamLog -Object ($sched | Select-Object Id, Name, Script, TimeZoneString, OneTime, Environment)
                    Show-UDModal -Content {
                        New-UDTypography -Text "Onboard scheduled for $schedDT" -Variant h5
                        New-UDTypography -Text 'Job status can be monitored from the PowerShell Universal Jobs page.' -Variant body2
                        New-UDTypography -Text "Script: $($OnboardScript.Name)" -Variant body2
                        New-UDTypography -Text "Job ID: $($sched.Id)" -Variant body2
                        New-UDTypography -Text "Workers: $($WORKERS -join ', ')" -Variant body2
                    } -Footer {
                        New-UDButton -Text 'Close' -OnClick {
                            Hide-UDModal
                            Checkpoint-IamCache -Scope User, Group -Force
                            Invoke-UDRedirect -Url '/home'
                        }
                    } -Persistent
                }
                else {

                    Write-IamLog -Level Information -Message "Creating account for $($session:AccountProperties['SamAccountName']) immediately."
                    $Job = Invoke-PSUScript -Script $OnboardScript -Credential (Get-PSFConfigValue -FullName PowerIAM.Cred.AD.Write) -Parameters @{ InputObject = $session:AccountProperties; Workers = $WORKERS; WorkflowType = 'Onboard' } -Environment 'PowerIAM' -Integrated

                    Write-IamLog -Level Information -Message "New user job executed by $User. Job ID: $($Job.Id)"
                    Show-UDModal -Content {
                        New-UDTypography -Text 'Creating account immediately.' -Variant h5
                        New-UDTypography -Text 'Job status can be monitored from the PowerShell Universal Jobs page.' -Variant body2
                        New-UDTypography -Text "Script: $($OnboardScript.Name)" -Variant body2
                        New-UDTypography -Text "Job ID: $($Job.Id)" -Variant body2
                        New-UDTypography -Text "Workers: $($WORKERS -join ', ')" -Variant body2
                    } -Footer {
                        New-UDButton -Text 'Close' -OnClick {
                            Hide-UDModal
                            Checkpoint-IamCache -Scope User, Group -Force
                            Invoke-UDRedirect -Url '/home'
                        }
                    } -Persistent
                }
            }
        } -ButtonVariant contained
        # end form
    } # end protectedsection
}