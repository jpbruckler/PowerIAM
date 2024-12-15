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
        $now = Get-Date
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

            $updateCache = $false

            # Retrieve config values
            $cacheKeyName = Get-PSFConfigValue -FullName "PowerIAM.Cache.$item.Key"
            $cacheObjProps = Get-PSFConfigValue "PowerIAM.Cache.$item.Properties"
            $cacheDataTTL = [int](Get-PSFConfigValue "PowerIAM.Cache.$item.TTL")
            $adFilterType = Get-PSFConfigValue "PowerIAM.Cache.$item.FilterType"
            $adFilterText = Get-PSFConfigValue "PowerIAM.Cache.$item.Filter"

            # Calculate cache expiration as timespan for Set-PSUCache
            $cacheExpires = $now.AddHours($cacheTTL)
            $cacheRemainingLife = $cacheExpires - $now

            # Get the current cache and last write time
            $currentCache = Get-PSUCache -Key $cacheKeyName
            $lastCacheWrite = Get-PSUCache -Key "$cacheKeyName.LastWriteTime"

            # Determine if the cache should be updated:
            # - If the force switch is provided, skip cache lifetime checks
            # - If the cache is empty or the last write time is null, update the cache
            # - If the cache will expire in 60 minutes or less, update the cache
            if (($PSBoundParameters.ContainsKey('Force') -and $Force -eq $true) -or $cacheRemainingLife.TotalMinutes -le 60) {
                Write-IamLog -Level Information -Message 'Force switch provided, skipping cache lifetime checks. Cache will be updated.'
                $updateCache = $true
            }
            elseif (($null -eq $currentCache) -or ($null -eq $lastCacheWrite)) {
                Write-IamLog -Level Debug -Message "Cache for $item is empty or last write time is null. Cache will be updated."
                $updateCache = $true
            }
            elseif ($cacheRemainingLife.TotalMinutes -le 60) {
                Write-IamLog -Level Debug -Message "Cache for $item expires soon. Cache will be updated."
                $updateCache = $true
            }
            else {
                Write-IamLog -Level Information -Message "Cache for $item is still valid. Skipping update."
                $status[$item].Status = 'Valid'
                $status[$item].CachedCount = $currentCache.Count
                $status[$item].LastWriteTime = $lastCacheWrite
            }

            if ($updateCache) {
                Write-IamLog -Level Information -Message "Cache for $item is expired or will expire soon. Updating cache."

                try {
                    $adCmdSplat = @{}
                    $adCmdSplat.Add($adFilterType, $adFilterText)
                    $adCmdSplat.Add('Properties', $cacheObjProps)

                    # Generate and process cache data from Active Directory.
                    switch ($item) {
                        'User' {

                            $cacheData = Get-ADUser @adCmdSplat
                            $cacheData = ProcessUserCache -Data $cacheData -CacheProperties $cacheObjProps
                        }
                        'Group' {
                            $cacheData = Get-ADGroup @adCmdSplat
                            $cacheData = ProcessGroupCache -Data $cacheData -CacheProperties $cacheObjProps
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