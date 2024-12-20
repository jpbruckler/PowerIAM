[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param(
    [Parameter(Mandatory = $true)]
    [hashtable] $TestData
)

BeforeAll {
    $Domain = 'dtmidstream.com'
    $Username = $TestData.GivenName + '.' + $TestData.Surname
}

Describe "TestData - <username>" {
    Context 'TicketNumber' {
        It 'TicketNumber should not be null or empty' {
            $TestData.TicketNumber | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SamAccountName' {
        It 'SamAccountName should not be null or empty' {
            $TestData.SamAccountName | Should -Not -BeNullOrEmpty
        }

        It 'Account should be unique' {
            $existingUser = Get-ADUser -Filter "SamAccountName -eq '$($TestData.SamAccountName)'" -ErrorAction SilentlyContinue
            $existingUser | Should -BeNullOrEmpty
        }

        It 'SamAccountName is in the correct format' {
            $TestData.SamAccountName.Substring(1) | Should -BeExactly $TestData.EmployeeID.Substring(1)
            $TestData.SamAccountName | Should -MatchExactly '^(u|c|v)\d{5}$'
        }

        It 'SamAccountName and Name properties are equal' {
            $TestData.SamAccountName | Should -BeExactly $TestData.Name
        }
    }

    Context 'UserPrincipalName' {
        It 'UserPrincipalName should not be null or empty' {
            $TestData.UserPrincipalName | Should -Not -BeNullOrEmpty
        }

        It 'UserPrincipalName should be unique' {
            $existingUser = Get-ADUser -Filter "UserPrincipalName -eq '$($TestData.UserPrincipalName)'" -ErrorAction SilentlyContinue
            $existingUser | Should -BeNullOrEmpty
        }

        It 'UserPrincipalName matches legal name (GivenName.Surname@domain)' {
            $TestData.UserPrincipalName | Should -Match ([regex]::Escape("$($TestData.GivenName).$($TestData.Surname)@$Domain"))
        }
    }

    Context 'Name' {
        It 'Name should not be null or empty' {
            $TestData.Name | Should -Not -BeNullOrEmpty
        }
    }

    Context 'GivenName' {
        It "GivenName should not be null or empty" {
            $TestData.GivenName | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Surname' {
        It "Surname should not be null or empty" {
            $TestData.Surname | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Manager' {
        It "Manager should not be null or empty" {
            $TestData.Manager | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Title' {
        It 'Title should not be null or empty' {
            $TestData.Title | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Department' {
        It 'Department should not be null or empty' {
            $TestData.Department | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Office' {
        It 'Office should not be null or empty' {
            $TestData.Office | Should -Not -BeNullOrEmpty
        }
    }

    Context 'EmployeeID' {
        It 'EmployeeID should not be null or empty' {
            $TestData.EmployeeID | Should -Not -BeNullOrEmpty
        }

        It 'EmployeeID is a 6-digit number' {
            $TestData.EmployeeID | Should -Match '\d{6}'
        }
    }

    Context 'DisplayName' {
        It 'DisplayName is "PreferredName Surname" or "GivenName Surname"' {
            # If PreferredName is not set, DisplayName should be GivenName Surname
            # Otherwise, DisplayName should be PreferredName Surname
            if ([string]::IsNullOrWhiteSpace($TestData.PreferredName)) {
                $displayName = "$($TestData.GivenName) $($TestData.Surname)"
            }
            else {
                $displayName = "$($TestData.PreferredName) $($TestData.Surname)"
            }

            $TestData.DisplayName | Should -BeExactly $displayName
        }
    }
}