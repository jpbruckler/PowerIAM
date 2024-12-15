function ProcessUserCache {
    param (
        [array]$Data,
        [array]$CacheProperties
    )

    foreach ($user in $Data) {
        if ($CacheProperties -contains 'Manager') {
            $manager = $Data | Where-Object { $_.DistinguishedName -eq $user.Manager } | Select-Object -First 1
            $user.Manager = $manager.DisplayName
        }
    }
    return $Data
}