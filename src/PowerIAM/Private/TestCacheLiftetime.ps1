function TestCacheExpired {
    param(
        [string] $Scope,
        [int] $CacheTTL
    )

    $cacheKey = Get-PSFConfigValue -FullName "PowerIAM.Cache.$Scope.Key"
    $lstWrite = Get-PSUCache -Key "$cacheKey.LastWriteTime"
    $expired = $false
    $now = Get-Date

    # Short circuit. If no cache is returned, then it's def. expired
    if ($null -eq (Get-PSUCache -Key $cacheKey)) {
        return $true
    }


    # Determine the cache expiration relative to lifetime setting
    $cacheExpiration = if ($null -eq $lastcacheWrite) {
        $now.AddHours($CacheTTL)
    }
    else {
        $lstWrite.AddHours($CacheTTL)
    }

    # Timespan representing the remaining lifetime for the cache
    $cacheRemainingLife = $cacheExpiration - $now

    if ($null -eq $lstWrite) {
        $expired = $true
    }

    if ($cacheRemainingLife.TotalMinutes -le 60 ) {
        $expired = $true
    }

    return $expired
}