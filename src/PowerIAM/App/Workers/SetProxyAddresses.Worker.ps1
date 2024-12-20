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
    'Write-IamLog:WorkerName' = 'SetProxyAddresses'
}

if ($InputData.proxyAddresses) {
    try {
        $identity = $InputData.SamAccountName
        $adUser = Get-ADUser -Identity $identity

        if ($adUser) {
            Write-IamLog -Message "Adding proxy addresses to '$($adUser.SamAccountName)'."
            Write-IamLog -Message "Set-ADUser -Identity $($adUser.SamAccountName) -Add @{proxyAddresses = @($($InputData.proxyAddresses) }"


            # Prepare the proxyAddresses array. This is required because Set-ADUser expects an array
            # of strings.
            $pa = [System.Collections.Generic.List[string]]::new()
            $InputData.proxyAddresses | ForEach-Object {
                $null = $pa.add($_)
            }

            Set-ADUser -Identity $adUser.SamAccountName -Add @{proxyAddresses = $pa.ToArray() } -ErrorAction Stop

            Write-IamLog -Message "Successfully added proxy addresses to '$($adUser.SamAccountName)'."
        }
        else {
            throw [System.InvalidOperationException]::New("No user object found with Identity '$($InputData.SamAccountName)'.")
        }
    }
    catch {
        $State.UpdateScriptData('ProxyAddresses', $PSItem)
        Write-IamLog -Level Error -Message "An error occurred while adding proxy addresses to '$identity'. $($PSItem.Exception.Message)"
        $e = [System.InvalidOperationException]::New("Failed to add proxy addresses to user: $identity")
        throw $e
    }
}
else {
    Write-IamLog -Message "Skipping adding proxy addresses to '$identity'. No proxy addresses provided."
}