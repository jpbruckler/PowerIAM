<#
.SYNOPSIS
    Creates a page to search for users within Active Directory.
.DESCRIPTION
    This script creates a page to search for users within Active Directory. The
    page includes a form to input a filter and a checkbox to use an LDAP filter.
    The page will display a table of objects based on the filter.
#>
New-UDPage -Url "/Search" -Name "Search" -Content {

    Write-IamAccessLog
    $Session:ObjProps = @('Name', 'DistinguishedName', 'ObjectGUID', 'DisplayName')
    $Session:DefaultFilter = "Name -like '*{0}*' -or SamAccountName -like '*{0}*' -or DisplayName -like '*{0}*'"
    if (-not ([string]::IsNullOrEmpty($Query['searchTerm']))) {
        $term = [System.Web.HttpUtility]::UrlDecode($Query['searchTerm'])
        $Session:Objects = Get-ADObject -Filter ($Session:DefaultFilter -f $term) -Properties $Session:ObjProps
        Sync-UDElement -Id 'adObjects'
    }
    New-UDTypography -Text 'Search Active Directory' -Variant h4
    New-UDCard -Content {
        New-UDElement -Tag 'p' -Content {
            'Search for objects in Active Directory. By default, the search will look for objects with a name, SamAccountName, or display name that contains the search term.'
        }
        New-UDForm -Content {
            New-UDTextbox -Label 'Filter' -Id 'filter'
            New-UDCheckBox -Label 'Use LDAP filter' -Id 'ldapFilter'
        } -OnSubmit {
            $splat = @{ Properties = $Session:ObjProps }
            if ($EventData.LdapFilter) {
                $splat['LDAPFilter'] = $EventData.filter
            }
            else {
                $splat['Filter'] = ($Session:DefaultFilter -f $EventData.Filter)
            }
            $Session:Objects = Get-ADObject @splat
            Sync-UDElement -Id 'adObjects'
        } -ButtonVariant contained
    }

    New-UDDynamic -Id 'adObjects' -Content {
        if ($null -eq $Session:Objects) {
            New-UDTypography -Text 'No objects found.' -Variant h4
            return
        }
        New-UDTable -Title 'Objects' -Data $Session:Objects -Columns @(
            New-UDTableColumn -Property Name -Title "Name" -Filter
            New-UDTableColumn -Property DisplayName -Title "Display Name" -Filter
            New-UDTableColumn -Property DistinguishedName -Title "Distinguished Name" -Filter
            New-UDTableColumn -Property objectClass -Title 'Type' -OnRender {
                $ObjectClass = $EventData.objectClass
                switch ($ObjectClass) {
                    'user' {
                        New-UDIcon -Icon 'user' -Color 'blue' -Title 'User'
                    }
                    'group' {
                        New-UDIcon -Icon 'usergroup' -Color 'green' -Title 'Group'
                    }
                    'organizationalUnit' {
                        New-UDIcon -Icon 'sitemap' -Color 'purple' -Title 'OU'
                    }
                }
            }
            New-UDTableColumn -Property ViewObject -Title "View Object" -Render {
                $Guid = $EventData.ObjectGUID
                New-UDButton -Text 'View Object' -OnClick {
                    Invoke-UDRedirect "/objectinfo/$Guid"
                }
            }
        ) -Filter
    }
}