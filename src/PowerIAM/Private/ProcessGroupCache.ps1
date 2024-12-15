function ProcessGroupCache {
    param (
        [array]$Data,
        [array]$CacheProperties
    )

    if ($CacheProperties -contains 'Members') {
        foreach ($group in $Data) {
            $memberCount = if ($group.Members) { $group.Members.Count } else { 0 }
            $group | Add-Member -MemberType NoteProperty -Name 'MemberCount' -Value $memberCount
        }
    }
    return $Data
}