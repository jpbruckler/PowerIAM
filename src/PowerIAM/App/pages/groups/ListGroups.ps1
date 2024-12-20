New-UDPage -Name 'Groups' -Url '/groups/list' -Content {
    Write-IamAccessLog
    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators', 'PowerIAM Operators', 'PowerIAM Users') -Children {
        $CacheKey = (Get-PSFConfigValue -FullName 'PowerIAM.Cache.Group.Key')
        $Data = Get-PSUCache -Key $CacheKey
        if ($null -eq $Data) {
            Show-UDToast -Message "Cache is empty. Refreshing cache at key $CacheKey" -Duration 5000 -Position topRight
            Checkpoint-IamCache -Scope Group -Force
            $Data = Get-PSUCache -Key $CacheKey
        }
        $Columns = @(
            New-UDTableColumn -Property SamAccountName -Title 'Account'-ShowSort -ShowFilter -DefaultSortColumn
            New-UDTableColumn -Property Description -Title 'Description' -ShowFilter -ShowSort
            New-UDTableColumn -Property ManagedBy -Title 'Manager'
            New-UDTableColumn -Property MembersCount -Title 'Member Count'
        )

        New-UDTable -Columns $Columns -LoadData {
            foreach ($Filter in $EventData.Filters) {
                $Data = $Data | Where-Object -Property $Filter.Id -Match $Filter.Value
            }

            $TotalCount = $Data.Count

            if (-not [string]::IsNullOrEmpty($EventData.OrderBy.Field)) {
                $Descending = $EventData.OrderDirection -ne 'asc'
                $Data = $Data | Sort-Object -Property ($EventData.orderBy.Field) -Descending:$Descending
            }

            $Data = $Data | Select-Object -First $EventData.PageSize -Skip ($EventData.Page * $EventData.PageSize)

            $Data | Out-UDTableData -Page $EventData.Page -TotalCount $TotalCount -Properties $EventData.Properties
        } -ShowFilter -ShowSort -ShowPagination -PageSize 50
    }
}