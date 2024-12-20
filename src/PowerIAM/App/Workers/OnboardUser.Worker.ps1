<#
.PARAMETER InputData
    InputData contains the form data.
.NOTES
    Throws InvalidIoperationException if an account with $AccountName is found in
    Active Directory.
#>
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    <#Category#>'PSReviewUnusedParameter',
    <#CheckId#>'',
    Justification = 'State parameter is only for reading.'
)]
param(
    $InputData,
    $State
)

$PSDefaultParameterValues = @{
    'Write-IamLog:WorkerName' = 'OnboardUser'
}

# Check if an AD user already exists with the given SamAccountName
try {
    $chkUser = Get-ADUser -Identity $InputData.SamAccountName
    if ($chkUser) {
        # this is a terminating error, can't create a user that already exists.
        $e = [System.InvalidOperationException]::New("User account with identity '$($InputData.SamAccountName)' already exists.")
        throw $e
    }
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    # Catches if Get-ADUser can't find the user, which in this case is the
    # expected output. This won't catch the InvalidOperationException thrown
    # if an existing user is found though. This preserves the intended behavior.
    $chkUser = $null
}

# Generate a temporary password that meets complexity and length requirements.
$defaultPwP = Get-ADDefaultDomainPasswordPolicy
$minPWLength = if ($defaultPwP.MinPasswordLength -ge 15) { $defaultPwP.MinPasswordLength } else { 15 }
$newAccountPW = New-IamRandomPassword -Length $minPWLength -MinSpecialChars 2 -MinUppercase 2 -MinLowerCase 2 -MinNumbers 2 -AsSecureString

# Setup required arguments to New-ADUser
$Splat = @{
    Name              = $InputData.SamAccountName
    AccountPassword   = $newAccountPW
    Enabled           = ([bool] $InputData.Enabled)
    UserPrincipalName = $InputData.UserPrincipalName
    GivenName         = $InputData.GivenName
    Surname           = $InputData.Surname
    DisplayName       = $InputData.DisplayName
    EmployeeID        = $InputData.EmployeeID
    EmailAddress      = $InputData.EmailAddress
    Path              = $InputData.Path
    Department        = $InputData.Department
    Title             = $InputData.Title
    Manager           = $null
    Office            = $InputData.Office
    OfficePhone       = $InputData.OfficePhone
    MobilePhone       = $InputData.MobilePhone
    Description       = "$($InputData.TicketNumber) Created by PowerIAM on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')."
}

if ($InputData.Manager) {
    $manager = Get-ADUser -Filter "SamAccountName -eq '$($($InputData.Manager -split '-')[1].trim())'"
    $Splat['Manager'] = $manager.DistinguishedName
}

# Array of properties to return in addition to default properties.
$userProps = @(
    'GivenName',
    'SurName',
    'EmployeeID',
    'DisplayName',
    'EmailAddress',
    'UserPrincipalName',
    'SamAccountName',
    'Enabled',
    'Department',
    'Title',
    'Manager',
    'Description',
    'Created',
    'DistinguishedName',
    'ObjectGUID',
    'MemberOf'
)

try {
    # Create the new user and return the object.
    Write-IamLog -Message "Creating new user account '$($InputObject.SamAccountName)' requested by $($InputObject.RequestedBy)."
    Write-IamLog -Message "Creating new user account '$($InputObject.SamAccountName)' requested by $($InputObject.RequestedBy)."
    $newAdUser = New-ADUser @splat -ErrorAction Stop -PassThru
    $userObject = $newAdUser | Get-ADUser -Properties $userProps | Select-Object $userProps

    Write-IamLog -Message "User account '$($InputObject.SamAccountName)' created successfully."

    Write-IamLog -Message 'Adding user to job state.'
    $State.AddUserObject(@{SamAccountName = $userObject.SamAccountName; ObjectGUID = $userObject.ObjectGUID })
}
catch {
    Write-IamLog -Level Error -Message "An error occurred while creating '$($InputObject.SamAccountName)'. Removing partially created account."
    Write-IamLog -Object $_

    $retryCount = 5
    do {
        Write-IamLog -Message "Retrying to remove partially created account '$($InputData.SamAccountName)'."
        $retryCount--
        try {
            Remove-ADUser -Identity $InputData.SamAccountName -Credential $Credential -Confirm:$false -ErrorAction Stop
            $retryCount = 0
        }
        catch {
            Write-IamLog -Level Error -Message "Failed to remove partially created account '$($InputData.SamAccountName)'."
            if ($retryCount -gt 0) {
                Write-IamLog -Level Information -Message 'Retrying in 5 seconds.'
                Start-Sleep -Seconds 5
            }
        }
    } while ($retryCount -gt 0)

    # throw an error so Invoke-IamWorkflow can catch it and handle it.
    $e = [System.InvalidOperationException]::New("Failed to create user: $($InputData.Name)")
}
finally {
    # Clear the password from memory.
    $newAccountPW.Dispose()

    if ($e) {
        throw $e
    }
    else {
        Write-Output @{
            UserObject = $userObject
        }
    }
    Write-IamLog -Message 'OnboardUser completed.'
}
