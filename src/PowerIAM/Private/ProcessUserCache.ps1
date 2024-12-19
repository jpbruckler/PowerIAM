function ProcessUserCache {

    <# UAC Flags
        0x00000001 = 'SCRIPT'
        0x00000002 = 'ACCOUNTDISABLE'
        0x00000008 = 'HOMEDIR_REQUIRED'
        0x00000010 = 'LOCKOUT'
        0x00000020 = 'PASSWD_NOTREQD'
        0x00000040 = 'PASSWD_CANT_CHANGE' # Note: Not set directly. Use permissions to control this.
        0x00000080 = 'ENCRYPTED_TEXT_PWD_ALLOWED'
        0x00000100 = 'TEMP_DUPLICATE_ACCOUNT'
        0x00000200 = 'NORMAL_ACCOUNT'
        0x00000800 = 'INTERDOMAIN_TRUST_ACCOUNT'
        0x00001000 = 'WORKSTATION_TRUST_ACCOUNT'
        0x00002000 = 'SERVER_TRUST_ACCOUNT'
        0x00010000 = 'DONT_EXPIRE_PASSWD'
        0x00020000 = 'MNS_LOGON_ACCOUNT'
        0x00040000 = 'SMARTCARD_REQUIRED'
        0x00080000 = 'TRUSTED_FOR_DELEGATION'
        0x00100000 = 'NOT_DELEGATED'
        0x00200000 = 'USE_DES_KEY_ONLY'
        0x00400000 = 'DONT_REQ_PREAUTH'
        0x00800000 = 'PASSWORD_EXPIRED'
        0x01000000 = 'TRUSTED_TO_AUTH_FOR_DELEGATION'
        0x04000000 = 'PARTIAL_SECRETS_ACCOUNT' # Available on newer domains (Win2012+)
    #>

    $AttributeMap = @{
        AccountExpirationDate = 'accountExpires'
        City                  = 'l'
        Company               = 'company'
        Country               = 'co'  # Friendly country name
        Created               = 'whenCreated'
        Department            = 'department'
        Description           = 'description'
        DirectReports         = 'directReports'
        DisplayName           = 'displayName'
        DistinguishedName     = 'distinguishedName'
        EmailAddress          = 'mail'
        EmployeeID            = 'employeeID'
        Enabled               = 'userAccountControl'  # Derived from bits in userAccountControl
        GivenName             = 'givenName'
        LastLogonTimestamp    = 'lastLogonTimestamp'
        LockedOut             = 'lockoutTime'         # Requires interpretation
        Manager               = 'manager'
        Mobile                = 'mobile'
        Modified              = 'whenChanged'
        ObjectGUID            = 'objectGUID'
        Office                = 'physicalDeliveryOfficeName'
        PasswordLastSet       = 'pwdLastSet'
        PasswordNeverExpires  = 'userAccountControl'   # Derived from bits in userAccountControl
        proxyAddresses        = 'proxyAddresses'
        SamAccountName        = 'sAMAccountName'
        SID                   = 'objectSID'
        Surname               = 'sn'
        TelephoneNumber       = 'telephoneNumber'
        ThumbnailPhoto        = 'thumbnailPhoto'
        Title                 = 'title'
        UserAccountControl    = 'userAccountControl'
        UserPrincipalName     = 'userPrincipalName'
    }

    $ds = New-Object System.DirectoryServices.DirectorySearcher
    $ds.Filter = '(&(objectCategory=person)(objectClass=user))'
    $ds.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
    $ds.PageSize = 2000

    $AttributeMap.Values | ForEach-Object {
        $null = $ds.PropertiesToLoad.Add($_)
    }

    $data = $ds.FindAll()

    foreach ($item in $data) {
        $user = @{}
        foreach ($friendlyName in $AttributeMap.Keys) {
            $ldapAttr = $AttributeMap[$friendlyName]

            if ($item.Properties[$ldapAttr]) {
                $value = $item.Properties[$ldapAttr][0]
                $user.Add($friendlyName, $value)
            }
            else {
                $user.Add($friendlyName, $null)
            }
        }

        $user.PasswordNeverExpires = (($user.UserAccountControl -band 0x10000) -ne 0)
        $user.PasswordExpired = (($user.UserAccountControl -band 0x800000) -ne 0)
        $user.Enabled = -not (($user.UserAccountControl -band 2) -ne 0)
        $user.LockedOut = (($user.UserAccountControl -band 0x10) -ne 0)

        $sidBytes = [byte[]]($item.Properties['objectSID'][0])
        $user.SID = [System.Security.Principal.SecurityIdentifier]::new($sidBytes, 0).Value
        $user.AccountExpirationDate = $user.AccountExpirationDate | ConvertFromADFileTime
        $user.LastLogonTimestamp = $user.LastLogonTimestamp | ConvertFromADFileTime
        $user.PasswordLastSet = $user.PasswordLastSet | ConvertFromADFileTime
        $user.ObjectGUID = [System.Guid]$user.ObjectGUID
        $user
    }
}