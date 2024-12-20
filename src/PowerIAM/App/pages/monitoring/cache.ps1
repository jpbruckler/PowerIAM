New-UDPage -Name 'Cache Settings' -Url '/monitoring/cache' -Content {
    Write-IamAccessLog
    Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators', 'PowerIAM Operators', 'PowerIAM Users') -Children {
        $ServerUrl = ($Headers['Referer'] -split '/PowerIAM')[0]
        $cacheScript = Get-PSUScript -Name 'PowerIAM\Checkpoint-IamCache'
        $cacheJobs = Get-PSUJob -Script $cacheScript -OrderBy EndTime -OrderDirection Descending
        $lastCacheJob = $cacheJobs | Where-Object { $_.Status -eq 'Completed' } | Select-Object -First 1

        New-UDTypography -Text 'PowerIAM Cache Jobs' -Variant h2
        New-UDTypography -Text "Last cache job run: $($lastCacheJob.EndTime)`n"

        <#
            Job Properties:
            Id
            CreatedTime
            StartTime
            EndTime
            Status
            ScriptFullPath
            Identity
            ComputerName
            PercentComplete
            Environment
            Schedule
        #>

        $TableData = @()
        $cacheJobs | ForEach-Object {
            $TableData += [PSCustomObject]@{
                Id              = $_.Id
                CreatedTime     = '{0:MM/dd/yy HH:mm:ss}' -f $_.CreatedTime
                StartTime       = '{0:MM/dd/yy HH:mm:ss}' -f $_.StartTime
                EndTime         = '{0:MM/dd/yy HH:mm:ss}' -f $_.EndTime
                Status          = $_.Status
                ScriptFullPath  = $_.ScriptFullPath
                Identity        = $_.Identity
                ComputerName    = $_.ComputerName
                PercentComplete = $_.PercentComplete
                Environment     = $_.Environment
                Schedule        = $_.Schedule
                Duration        = '{0:hh}h:{0:mm}m:{0:ss}s' -f ($_.EndTime - $_.StartTime)
            }
        }

        $TableData = $TableData | Sort-Object -Property Id
        $Columns = @(
            New-UDTableColumn -Property 'Id' -Title 'ID' -OnRender {
                $JobId = $EventData.Id
                New-UDLink -Text $JobId -Url "$ServerUrl/admin/automation/jobs/$JobId"
            }
            New-UDTableColumn -Property 'Status' -Title 'Status' -OnRender {
                $Status = $EventData.Status
                if ($Status -eq 'Completed') {
                    New-UDIcon -Icon 'circle-check' -Color '#58C322'
                }
                elseif ($Status -eq 'Failed') {
                    New-UDIcon -Icon 'circle-xmark' -Color '#D41111'
                }
                else {
                    New-UDIcon -Icon 'circle-exclamation' -Color '#FFAB1A'
                }
            }
            New-UDTableColumn -Property 'StartTime' -Title 'Start Time' -OnRender {
                $StartTime = $EventData.StartTime
                '{0:MM/dd/yy HH:mm:ss}' -f $StartTime
            }
            New-UDTableColumn -Property 'Duration' -Title 'Duration'
            New-UDTableColumn -Property 'ScriptFullPath' -Title 'Script Full Path'
            New-UDTableColumn -Property 'ComputerName' -Title 'Computer Name'
            New-UDTableColumn -Property 'Environment' -Title 'Environment'
            New-UDTableColumn -Property 'Schedule' -Title 'Schedule'
        )

        Protect-UDSection -Role @('Administrator', 'PowerIAM Administrators') -Children {
            New-UDStack -Direction row -Children {
                New-UDButton -Text 'Force User Cache Update' -OnClick {
                    $Job = Invoke-PSUScript -Name 'PowerIAM\Checkpoint-IamCache' -Parameters @{ Scope = 'User'; Force = $true }
                    Show-UDToast -Message "User cache job started. Job ID: $($Job.Id)" -Duration 5000
                }
                New-UDButton -Text 'Force Group Cache Update' -OnClick {
                    $Job = Invoke-PSUScript -Name 'PowerIAM\Checkpoint-IamCache' -Parameters @{ Scope = 'Group'; Force = $true }
                    Show-UDToast -Message "Group cache job started. Job ID: $($Job.Id)" -Duration 5000
                }
            }
        }

        New-UDDynamic -Id 'dynCacheTable' -Content {
            New-UDTable -Data $TableData -Columns $Columns -Paging -PageSize 25 -PageSizeOptions @(25, 50, 100) -ShowSort -ShowSearch
        } -AutoRefresh -AutoRefreshInterval 300

        New-UDButton -Text 'Update Table' -OnClick {
            Sync-UDElement -Id 'dynCacheTable'
        }
    }
}