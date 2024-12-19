function ProcessGroupCache {
    $AttributeMap = @{
        SamAccountName    = 'samaccountname'
        Description       = 'description'
        DistinguishedName = 'distinguishedname'
        Changed           = 'whenChanged'
        Created           = 'whenCreated'
        Members           = 'member'
        ObjectGUID        = 'objectguid'
    }

    $ds = New-Object System.DirectoryServices.DirectorySearcher
    $ds.Filter = '(objectCategory=group)'
    $ds.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
    $ds.PageSize = 2000
    $AttributeMap.Values | ForEach-Object {
        $null = $ds.PropertiesToLoad.Add($_)
    }
    $groups = $ds.FindAll()



    foreach ($item in $groups) {
        $group = @{}

        foreach ($friendlyName in $AttributeMap.Keys) {
            $ldapAttr = $AttributeMap[$friendlyName]
            if ($friendlyName -eq 'Members') {
                $value = $item.Properties[$ldapAttr]
                $group.Add($friendlyName, $value)
            }
            elseif ($item.Properties[$ldapAttr]) {
                $value = $item.Properties[$ldapAttr][0]
                $group.Add($friendlyName, $value)
            }
            else {
                $group.Add($friendlyName, $null)
            }
        }

        $group.ObjectGUID = [System.GUID]$group.ObjectGUID
        $group
    }
}