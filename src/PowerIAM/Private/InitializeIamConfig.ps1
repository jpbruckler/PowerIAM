function InitializeIamConfig {
    <#
    .SYNOPSIS
        Initializes the PowerIAM configuration.

    .DESCRIPTION
        Initializes the PowerIAM configuration. This function is called by the PowerIAM
        module to set default values for the configuration settings. It also registers
        custom validation for certain settings.

        Settings are stored in the PowerShell Framework configuration system. For more
        information on the configuration system, see:
        https://psframework.org/documentation/documents/psframework/configuration.html
    #>
    [CmdletBinding()]
    param()

    process {
        $PSDefaultParameterValues = @{
            'Set-PSFConfig:Module'       = 'PowerIAM'
            'Set-PSFConfig:Initialize'   = $true       # https://psframework.org/documentation/documents/psframework/configuration/initialize.html
            'Set-PSFConfig:ModuleExport' = $true
        }

        # Custom validation for cache filter
        Register-PSFConfigValidation -Name 'PowerIAM.CacheFilterType' -ScriptBlock {
            param( $Value )
            $Result = [PSCustomObject]@{
                Success = $True
                Value   = $null
                Message = ''
            }

            try {
                $AllowedSet = @('LDAPFilter', 'Filter')
                if ($Value -notin $AllowedSet) {
                    throw "Value '$Value' not in expected set of $($AllowedSet -join ',')"
                }
            }
            catch {
                $Result.Message = $PSItem.Exception.Message
                $Result.Success = $False
                return $Result
            }

            $Result.Value = $Value

            return $Result
        }

        # ----------------------------------------------------------------------
        #region General Settings
        # ----------------------------------------------------------------------
        try {
            $PsuInfo = Get-PSUInformation -ErrorAction Stop
        }
        catch {
            $PsuInfo = [PSCustomObject]@{
                Version = '0.0.0'
            }
        }
        Set-PSFConfig -Name PSU.ServerFQDN -Value ([System.Net.Dns]::GetHostByName($env:computerName)).Hostname -Default 'localhost.example.com' -Description 'The fully qualified domain name of the PowerShell Universal server. Used in Email notifications.'
        Set-PSFConfig -Name PSU.AppToken -Value '' -Default 'PowerIAMAppToken' -Description 'The name of the PowerShell Universal secret that contains the PowerShell Univeral AppToken that PowerIAM should use when interacting with PowerShell Universal.'
        Set-PSFConfig -Name PSU.MajorVersion -Value ([version]($PsuInfo).Version).Major -Description 'The major version of PowerShell Universal.'
        #endregion

        # ----------------------------------------------------------------------
        #region Paths
        # ----------------------------------------------------------------------
        $ModuleRoot = $MyInvocation.MyCommand.Module.Path | Split-Path -Parent
        Set-PSFConfig -Name ModulePath -Value $ModuleRoot -Hidden
        Set-PSFConfig -Name AppFolder -Value (Join-Path $ModuleRoot -ChildPath 'App') -Hidden
        Set-PSFConfig -Name WF.Workers.Dir -Value (Join-Path $ModuleRoot -ChildPath 'App\Workers') -Validation string -Description 'Path on disk where workflow steps (script blocks) are stored.'
        #endregion

        # ----------------------------------------------------------------------
        #region User cache settings
        # ----------------------------------------------------------------------
        #   Filter
        #       - The filter to use when retrieving users
        #   FilterType
        #       - LDAP vs. PowerShell
        Set-PSFConfig -Name Cache.User.Key -Value 'PowerIAM.Cache.User' -Description "Key name used to retrieve cached user information from PowerShell Universal's cache."
        Set-PSFConfig -Name Cache.User.Filter -Value '*' -Validation string -Description 'Search filter used to retrieve users from Active Directory'
        Set-PSFConfig -Name Cache.User.FilterType -Value 'Filter' -Validation PowerIAM.CacheFilterType -Description "Search filter type to use to retrieve users from Active Directory. Either 'Filter' or 'LDAPFilter'."
        Set-PSFConfig -Name Cache.User.TTL -Value 12 -Initialize -Validation integerpositive -Description 'The duration in hours that the group cache should be kept for.'

        Set-PSFConfig -Name Cache.User.Properties -Value @(
            'SamAccountName',
            'UserPrincipalName',
            'ObjectGUID',
            'Enabled',
            'DistinguishedName',
            'DirectReports',
            'GivenName',
            'Surname',
            'DisplayName',
            'EmailAddress',
            'Department',
            'Title',
            'Office',
            'TelephoneNumber',
            'Mobile',
            'EmployeeID',
            'UserAccountControl',
            'ThumbnailPhoto',
            'LockedOut',
            'Manager',
            'SID',
            'LastLogon',
            'Created',
            'Modified',
            'StreetAddress',
            'PasswordLastSet',
            'PasswordExpired',
            'AccountExpirationDate'
        ) -Validation stringarray -Description 'An array of properties to cache for user objects.'
        #endregion

        # ----------------------------------------------------------------------
        #region Group cache settings
        # ----------------------------------------------------------------------
        Set-PSFConfig -Name Cache.Group.Key -Value 'PowerIAM.Cache.Group' -Description "Key name used to retrieve cached group information from PowerShell Universal's cache."
        Set-PSFConfig -Name Cache.Group.Filter -Value '*' -Validation string -Description "Search filter used to retrieve groups from Active Directory"
        Set-PSFConfig -Name Cache.Group.FilterType -Value 'Filter' -Validation PowerIAM.CacheFilterType -Description "Search filter type to use to retrieve groups from Active Directory. Either 'Filter' or 'LDAPFilter'."
        Set-PSFConfig -Name Cache.Group.TTL -Value 12 -Validation integerpositive -Description "The duration in hours that the group cache should be kept for."
        Set-PSFConfig -Name Cache.Group.Properties -Value  @(
            'SamAccountName',
            'ObjectGUID',
            'DistinguishedName',
            'GroupCategory',
            'GroupScope',
            'Description',
            'ManagedBy',
            'Members',
            'SID'
        ) -Validation stringarray -Description "An array of properties to cache for group objects."
        #endregion

        # ----------------------------------------------------------------------
        #region Workflow Settings
        # ----------------------------------------------------------------------

        #endregion

        # ----------------------------------------------------------------------
        #region Credential Settings
        # ----------------------------------------------------------------------
        Set-PSFConfig -Name Cred.AD.Read -Value '' -Validation string -Description "The name of the PowerShell Universal credential to use for Active Directory Read operations. If blank, the identity of the service account running PowerShell Universal service will be used."
        Set-PSFConfig -Name Cred.AD.Write -Value '' -Validation string -Description "The name of the PowerShell Universal credential to use for Active Directory write operations."
        #endregion

        # ----------------------------------------------------------------------
        #region Active Directory Settings
        # ----------------------------------------------------------------------
        Set-PSFConfig -Name AD.EmailDomain -Value '' -Description "The domain portion of user email addresses. e.g. for john@example.com, set this to 'example.com'"
        Set-PSFConfig -Name AD.DomainInfo -Value @{} -Description 'Information about the Active Directory domain.'
        Set-PSFConfig -Name AD.ObjectMap -Value $([System.Collections.ArrayList]::new()) -Description 'An array of rules to map AD object properties to OUs and/or groups.'
        Set-PSFConfig -Name AD.User.DefaultGroup -Value $([System.Collections.ArrayList]::new()) -Description 'The default groups to add new users to. Applied if no ObjectMap rule matches.'
        Set-PSFConfig -Name AD.User.DefaultOU -Value '' -Description "The default OU to create new users in."
        Set-PSFConfig -Name AD.User.OffboardOU -Value '' -Description "The OU to move users to when offboarding."
        Set-PSFConfig -Name AD.User.OffboardAction -Value 'DisableAndMove' -Description 'The action to take when offboarding a user account.'

        Set-PSFConfig -Name AD.Group.DefaultOU -Value '' -Description "The default OU to create new groups in."
        Set-PSFConfig -Name AD.Group.DefaultScope -Value 'Global' -Description "The default group scope to use when creating new groups."
        Set-PSFConfig -Name AD.Group.DefaultCategory -Value 'Security' -Description "The default group category to use when creating new groups."

        Set-PSFConfig -Name AD.Data.UserOUs -Value $([System.Collections.ArrayList]::new()) -Description 'An array OU name and OU DN key/value pairs to populate the user OU dropdown.'
        Set-PSFConfig -Name AD.Data.GroupOUs -Value $([System.Collections.ArrayList]::new()) -Description 'An array OU name and OU DN key/value pairs to populate the group OU dropdown.'

        #endregion

        # ----------------------------------------------------------------------
        #region Form Data Settings
        # ----------------------------------------------------------------------
        Set-PSFConfig -Name Data.Departments -Value @()  -Description 'Form data for the user creation form.'
        Set-PSFConfig -Name Data.Offices -Value @() -Description 'Form data for the user creation form.'

        #endregion

        # ----------------------------------------------------------------------
        #region Email Notification Settings
        # ----------------------------------------------------------------------
        Set-PSFConfig -Name Email.HeaderLogo -Value '' -Description 'Path to the logo to use in the email header. Either the full path, or the name of a file in the PowerIAM\App\Assets folder.'
        Set-PSFConfig -Name Email.FooterLogo -Value '' -Description 'Path to the logo to use in the email footer. Either the full path, or the name of a file in the PowerIAM\App\Assets folder.'
        Set-PSFConfig -Name Email.From -Value '' -Description 'The email address to send notifications from.'
        Set-PSFConfig -Name Email.Recipients -Value ([System.Collections.Generic.List[hashtable]]::new()) -Description 'An array of email addresses to send notifications to.'
        Set-PSFConfig -Name Email.AppSecretName -Value 'EmailAppSecret' -Description 'The name of the PowerShell Universal variable that contains the Graph API secret.'
        Set-PSFConfig -Name Email.AppClientID -Value 'EmailClientID' -Description 'The name of the PowerShell Universal variable that contains the Graph API client ID.'
        Set-PSFConfig -Name Azure.TenantID -Value 'AzureTenantID' -Description 'The name of the PowerShell Universal variable that contains the Azure Tenant ID.'
        #endregion

        # ----------------------------------------------------------------------
        #region File Pickup Settings
        # ----------------------------------------------------------------------
        Set-PSFConfig -Name FilePickup.Path -Value '' -Description 'The path to monitor for new files.'
        Set-PSFConfig -Name FilePickup.Filter -Value '*' -Description 'The filter to use when monitoring the path for new files.'
        Set-PSFConfig -Name FilePickup.Recursive -Value $false -Description 'Whether to monitor the path recursively.'
        Set-PSFConfig -Name FilePickup.Interval -Value 5 -Description 'The interval in seconds to check for new files.'
        #endregion

        if ($script:MODULE.ModuleVersion) {
            Set-PSFConfig -Name ModuleVersion -Value $script:MODULE.ModuleVersion.ToString() -Hidden
        }

        Export-PSFConfig -ModuleName $MyInvocation.MyCommand.ModuleName -Scope FileSystem
        Import-PSFConfig -ModuleName $MyInvocation.MyCommand.ModuleName -Scope FileSystem
    }
}