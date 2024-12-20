New-UDPage -Name 'Offboard User' -Url '/users/offboard' -Title 'Offboard User' -Content {
    Write-IamAccessLog

    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators', 'PowerIAM Operators') -Children {
        $session:UserList = $null
        $session:OffboardUser = $null

        New-UDCard -Content {
            New-UDHeading -Size 4 -Text 'User Offboarding'
            New-UDParagraph -Text 'Search for user by user or display name.'
            New-UDTextbox -Id 'txtUser' -Label 'Offboard Account' -
            New-UDButton -Text 'Search' -OnClick {
                $searchString = (Get-UDElement -Id 'txtUser').Value
                if ($searchString.Length -lt 3) {
                    Show-UDToast -Message 'Search string must be at least 3 characters.' -Duration 5000 -Position topRight
                    return
                }
                $session:UserList = Get-ADUser -Filter ("SamAccountName -like '*{0}*' -OR DisplayName -like '*{0}*'" -f $searchString) -Properties DisplayName
                Sync-UDElement -Id 'offboardUserTable'
            }
        }

        New-UDDynamic -Id 'offboardUserTable' -Content {

            if ($null -eq $session:UserList) {
                return
            }

            New-UDTable -Id 'offboardUserTable' -Columns @(
                New-UDTableColumn -Property SamAccountName -Title 'Account'
                New-UDTableColumn -Property DisplayName -Title 'Display Name'
                New-UDTableColumn -Property UserPrincipalName -Title 'UPN'
            ) -Data $session:UserList -OnRowSelection {
                $session:OffboardUser = $EventData
            } -ShowSelection
        }

        New-UDButton -Text 'Offboard User' -OnClick {
            #Show-UDToast -Message 'Offboard User' -Duration 5000 -Position topRight
            #Show-UDObject $session:OffboardUser
            $OffboardScript = Get-PSUScript -Name 'PowerIAM\Invoke-IamWorkflow'
            $Workers = 'OffboardUser'

            Write-IamLog -Level Information -Object @{
                Action      = 'OffboardUserFromForm'
                InitiatedBy = $User
                From        = $RemoteIpAddress
                Headers     = $Headers
            }

            $splat = @{
                InputObject  = $session:OffboardUser
                Workers      = $Workers
                WorkflowType = 'Offboard'
                Environment  = 'PowerIAM'
                Script       = $OffboardScript
            }
            $Job = Invoke-PSUScript @splat
            Write-IamLog -Level Information -Message "Offboard user job executed by $User. Job ID: $($Job.Id)"
            Show-UDModal -Content {
                New-UDTypography -Text 'Offboarding account immediately.' -Variant h5
                New-UDTypography -Text 'Job status can be monitored from the PowerShell Universal Jobs page.' -Variant body2
                New-UDTypography -Text "Script: $($OnboardScript.Name)" -Variant body2
                New-UDTypography -Text "Job ID: $($Job.Id)" -Variant body2
                New-UDTypography -Text "Workers: $($Workers -join ', ')" -Variant body2
            } -Footer {
                New-UDButton -Text 'Close' -OnClick {
                    Hide-UDModal
                    Checkpoint-IamCache -Scope User, Group -Force
                    Invoke-UDRedirect -Url '/home'
                }
            } -Persistent
        }
    }
}