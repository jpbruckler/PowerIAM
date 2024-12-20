<#
.SYNOPSIS
    Creates a new user using a stepper form.
.NOTES
    The $Body variable will contain a JSON string that contains the current state of the stepper.
    You will receive information about the fields that have been defined within the stepper and info
    about the current step that has been completed. The $Body JSON string will have the following
    format:

        {
            context: {
                txtStep1: "value1",
                txtStep2: "value2",
                txtStep3: "value3"
            },
            currentStep: 0
        }
#>
New-UDPage -Url '/users/new' -Name 'New User' -Content {
    New-UDTypography -Text 'Create a new user' -Variant 'h2'
    $StackSpacing = 3
    #$DefaultEmailDomain = Get-PSFConfigValue -FullName PowerIAM.AD.EmailDomain
    #$UserData = Get-IamUserCache
    #$GroupData = Get-IamGroupCache
    #$FailedIcon = New-UDIcon -Icon exclamation -Color '#9b2226'
    $MandatoryIcon = New-UDIcon -Icon 'asterisk' -Color '#780000'

    New-UDStepper -Steps {
        New-UDStep -Id 'step1' -Label 'Step 1' -Content {
            New-UDCard -Content {
                New-UDStack -Children {
                    New-UDStack -Id 'LeftColumn-Inner-Left' -Children {
                        New-UDTextbox -Id 'GivenName' -Label 'First Name' -Icon $MandatoryIcon -Value $EventData.Context.GivenName
                        New-UDTextbox -Id 'Surname' -Label 'Last Name' -Icon $MandatoryIcon -Value $EventData.Context.Surname
                        New-UDTextbox -Id 'EmployeeID' -Label 'Employee ID' -Icon $MandatoryIcon  -MaximumLength 6 -Value $EventData.Context.EmployeeID
                    } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth

                    New-UDStack -Id 'LeftColumn-Inner-Right' -Children {
                        New-UDTextbox -Id 'OfficePhone' -Label 'Office Phone' -Value $EventData.Context.OfficePhone
                        New-UDTextbox -Id 'MobilePhone' -Label 'Mobile Phone' -Value $EventData.Context.MobilePhone
                        New-UDSelect -Id 'UserType' -Label 'Account Type' -Option {
                            New-UDSelectOption -Name 'Employee'     -Value 'User'
                            New-UDSelectOption -Name 'Contractor'   -Value 'Contractor'
                            New-UDSelectOption -Name 'Vendor'       -Value 'Vendor'
                        } -OnChange {
                            Sync-UDElement -Id 'dynAccountInfo'
                        } -DefaultValue $EventData.Context.UserType -Variant 'outlined'
                    } -Spacing $StackSpacing -Direction column -JustifyContent space-between -FullWidth
                } -Spacing 2 -FullWidth -Direction row -JustifyContent space-between

                New-UDStack -Children {
                    New-UDTextbox -Id 'TicketNumber' -Label 'Ticket Number' -Icon $MandatoryIcon
                } -Direction column -JustifyContent space-between
            }
        }
        #region Step 2
        New-UDStep -Id 'step2' -Label 'Step 2' -Content {
            # -----------------------------------------------------------------
            #region Position Information
            # =================================================================
            # Form fields below are for the position information of the user.
            # The card is a container for the form fields, and the different
            # fields are placed in a stack to ensure they are displayed in two
            # columns.
            New-UDTypography -Text 'Position Information' -Variant h4
            #endregion Position Information
        }
        #endregion Step 2

        New-UDStep -Id 'step3' -Label 'Step 3' -Content {
            New-UDTypography -Text 'Review your information'
        }
    } -OnFinish {
        Show-UDObject $EventData
    }
}