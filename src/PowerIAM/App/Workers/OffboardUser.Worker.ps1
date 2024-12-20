param(
    $InputObject,
    $State
)

$PSDefaultParameterValues = @{
    'Write-IamLog:WorkerName' = 'OffboardUser'
}

Write-IamLog -Message "Offboarding $($InputObject.Count) user(s)." -Level Information

$Description = '; Offboard by PowerIAM on {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$OffboardAction = Get-PSFConfigValue -FullName PowerIAM.AD.User.OffboardAction
if ($OffboardAction -match 'Move') {
    $TargetOU = Get-PSFConfigValue -FullName PowerIAM.AD.User.OffboardOU
}

$CredentialName = Get-PSFConfigValue -FullName PowerIAM.Cred.AD.Write
$Credential = Get-ChildItem "Secret:$CredentialName"


if ($null -eq $Credential) {
    throw ([System.InvalidOperationException]::New("Invalid Active Directory write credential configured ($CredentialName)."))
}

foreach ($User in $InputObject) {
    Write-IamLog -Message "Offboarding user $($User.SamAccountName)" -Level Information
    $adUser = Get-ADUser -Identity $User.SamAccountName -Properties DisplayName, Manager, DirectReports, Description
    $directReports = $adUser.DirectReports
    $State.AddUserObject(@{SamAccountName = $adUser.SamAccountName; ObjectGUID = $adUser.ObjectGUID})

    if ($directReports) {
        $inlineMgr = (Get-ADUser -Identity $adUser.Manager).SamAccountName
        Write-IamLog -Message "$($User.SamAccountName) has direct reports. Updating downlevel accounts' Manager to $inlineMgr" -Level Information
        $directReports = $directReports | ForEach-Object {
            Set-ADUser -Identity $_ -Manager $adUser.Manager -Credential $Credential
            Write-IamLog -Message "Updated Manager for $($_) to $inlineMgr" -Level Information
        }
    }

    try {
        Write-IamLog -Message "Disabling $($User.SamAccountName)" -Level Information
        Disable-ADAccount -Identity $User.SamAccountName -Credential $Credential
        Set-ADUser -Identity $User.SamAccountName -Description ('{0}{1}' -f $adUser.Description, $Description) -Credential $Credential
    }
    catch {
        $FailMessage = "Failed to offboard $($User.SamAccountName). $($_.Exception.Message)"
        Write-IamLog -Message $FailMessage -Level Error

        # throw exception to Invoke-IamWorkflow
        $e = [System.InvalidOperationException]::New($FailMessage)
        throw $e
    }

    if ($OffboardAction -match 'Move') {
        try {
            Write-IamLog -Message "Moving $($User.SamAccountName) to $TargetOU" -Level Information
            Move-ADObject -Identity $adUser.ObjectGUID -TargetPath $TargetOU -Credential $Credential -ErrorAction Stop
        }
        catch {
            $FailMessage = "Failed to move user $($User.SamAccountName). $($_.Exception.Message)"
            Write-IamLog -Message $FailMessage -Level Error

            # throw exception to Invoke-IamWorkflow
            $e = [System.InvalidOperationException]::New($FailMessage)
            throw $e
        }
    }
}