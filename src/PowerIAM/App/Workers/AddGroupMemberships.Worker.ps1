<#
.PARAMETER InputData
    InputData contains the form data.
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
    'Write-IamLog:WorkerName' = 'AddGroupMemberships'
}

$groupsAdded = @()
$errGroup = @()

# Check if an AD user already exists with the given SamAccountName
try {
    $User = Get-ADUser -Identity $InputData.SamAccountName
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    # Catches if Get-ADUser can't find the user, which in this case is the
    # expected output. This won't catch the InvalidOperationException thrown
    # if an existing user is found though. This preserves the intended behavior.
    $e = [System.InvalidOperationException]::New("No user account with identity '$($InputData.SamAccountName)' found. Cannot add group memberships.")
    throw $e
}

foreach ($Group in $InputData.GroupMemberships) {
    $chkGroup = Get-ADGroup -Identity $Group
    if (-not $chkGroup) {
        Write-IamLog -Level Warning -Message "Group '$Group' not found in Active Directory."
        continue;
    }

    try {
        Write-IamLog -Message "Adding user '$($User.SamAccountName)' to group '$Group'."
        Add-ADGroupMember -Identity $Group -Members $User.SamAccountName
        $groupsAdded += $Group
    }
    catch {
        $errGroup += $Group
        Write-IamLog -Level Error -Message "Failed to add user '$($User.SamAccountName)' to group '$Group'."
    }
}
$State.AddGroupObject($groupsAdded)
$State.UpdateScriptData('GroupsAdded', $groupsAdded)


if ($errGroup.Count -gt 0) {
    $e = [System.InvalidOperationException]::New("Failed to add user to group(s): $($errGroup -join ', ').")
    throw $e
}
else {
    return @{
        'GroupsAdded' = $groupsAdded
    }
}