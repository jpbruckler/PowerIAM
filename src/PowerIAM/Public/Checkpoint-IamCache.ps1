function Checkpoint-IamCache {
    <#
    .SYNOPSIS
        Caches user or group objects from Active Directory in the PowerShell
        Universal cache.

    .DESCRIPTION
        Queries Active Directory for user or group information, depending on the
        value provided to the item parameter. The information cached depends
        on the module settings for PowerIAM.Cache.User.Properties and
        PowerIAM.Cache.Group.Properties.

        When called, this will check the current lifetime remaining for the cache
        specified with -Scope. If the remaining lifetime is 10 minutes or less,
        or if the -Force switch is provided, this will update the cache with
        new information queried from Active Directory.

    .PARAMETER Scope
        Either User or Group. Sets the scope of objects to cache.

    .PARAMETER Force
        Causes a new checkpoint be taken regardless of the lifetime remaining in
        the current cache.

    .EXAMPLE
        Checkpoint-IamCache -Scope User

        Checks if the cache lifetime remaining for the user cache is less than
        10 minutes, and if so overwrites the existing cache with data queried
        from Active Directory.

    .OUTPUTS
        [System.Collections.Hashtable]

        Contains the following keys:
        - Status: 'Valid' if the cache is still valid, 'Success' if the cache was
          updated, or 'Failed' if the cache update failed.
        - CachedCount: The number of objects in the cache.
    .NOTES
        See about_PowerIAMSettings
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter( )]
        [ValidateSet('User', 'Group')]
        [string[]] $Scope = @('User', 'Group'),
        [switch] $Force
    )

    begin {
        # Determine if cache persistence is enabled. Cache persistence requires
        # PowerShell Universal 5 or higher.
        try {
            $PsuVersion = ([version](Get-PSUInformation).Version).Major
        }
        catch {
            $PsuVersion = 0
        }

        if ($PsuVersion -lt 5) {
            Write-IamLog -Level Warning -Message 'PowerShell Universal version 5 or higher is required for cache persistence.'
        }
        else {
            Write-IamLog -Level Debug -Message 'PowerShell Universal version 5 or higher detected. Cache persistence is enabled.'
            $PSDefaultParameterValues['Set-PSUCache:Persist'] = $true
        }
    }
    process {
        $status = @{
            Scope = $Scope
            Status = $null
        }

        foreach ($item in $Scope) {
            $status.Add($item, @{
                Status      = $null
                CachedCount = $null
                LastWriteTime = $null
            })
            # Retrieve config values
            $cacheKeyName = Get-PSFConfigValue -FullName "PowerIAM.Cache.$item.Key"
            $cacheTTL = [int]( Get-PSFConfigValue "PowerIAM.Cache.$Scope.TTL")

            # Set defaults
            $updateCache = $false

            $result = @{
                Timestamp   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.ffff'
                Status      = $null
                Item        = $item
                CacheKey    = $cacheKeyName
                CachedCount = 0
            }
            Write-IamLog -Level Debug -Message "Checking PowerIAM cache for scope: $item"

            # check whether cache needs to be reset
            if ($PSBoundParameters.ContainsKey('Force') -and $Force -eq $true) {
                Write-IamLog -Level Information -Message 'Force switch provided, skipping cache lifetime checks. Cache will be updated.'
                $updateCache = $true
            }
            else {
                $updateCache = TestCacheExpired -Scope $item -CacheTTL $cacheTTL

                if ($updateCache) {
                    Write-IamLog -Level Information -Message "Cache for $item is expired or will expire soon. Updating cache."
                }
                else {
                    Write-IamLog -Level Information -Message "Cache for $item is still valid. Skipping update."
                    $status[$item].Status = 'Valid'
                    $status[$item].CachedCount = (Get-PSUCache -Key $cacheKeyName).Count
                    $status[$item].LastWriteTime = (Get-PSUCache -Key "$cacheKeyName.LastWriteTime")
                }
            }
            #end updateCache check

            if ($updateCache) {
                Write-IamLog -Level Information -Message "Cache for $item is expired or will expire soon. Updating cache."

                try {
                    # Generate and process cache data from Active Directory.
                    switch ($item) {
                        'User' {
                            $cacheData = ProcessUserCache
                        }
                        'Group' {
                            $cacheData = ProcessGroupCache
                        }
                    }

                    # Set persistent cache values
                    $cacheItems = @(
                        @{
                            Key         = "$cacheKeyName.LastWriteTime"
                            Value       = (Get-Date)
                            ErrorAction = 'SilentlyContinue'
                        },
                        @{
                            Key                       = $cacheKeyName
                            Value                     = $cacheData
                            AbsoluteExpirationFromNow = [TimeSpan]::FromHours($cacheDataTTL)
                            ErrorAction               = 'SilentlyContinue'
                        }
                    )

                    $cacheItems | ForEach-Object {
                        $splat = $_.Clone()
                        Set-PSUCache @splat
                    }

                    Write-IamLog -Level Information -Message "Cache for $item has been updated using key '$cacheKeyName'."
                    $result = @{
                        Status      = 'Success'
                        CachedCount = $cacheData.Count
                    }
                    return $result
                }
                catch {
                    Write-IamLog -Level Error -Message "Failed to write to cache '$cacheKeyName'. $item cache was not updated"
                    Write-IamLog -Level Error -Message $_.Exception.Message
                    Set-PSUCache -Key "$cacheKeyName.LastWriteTime" -Value $null
                    $result = @{
                        Status = 'Failed'
                    }
                    return $result
                }
            }
        }
    }
}