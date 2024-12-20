<#
.PARAMETER InputData
    InputData contains the form data.
.PARAMETER State
    State parameter is only for reading, but contains the state of the workflow.
#>
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    <#Category#>'PSReviewUnusedParameter',
    <#CheckId#>'',
    Justification = 'State parameter is only for reading.'
)]
param(
    $InputData,
    $State
)
Import-Module PSHTML
$Users = $State.CommonData.UserObjects
$Job = Get-PSUJob -Id $State.JobID
$FailedSteps = $State.Results | Where-Object Status -EQ 'Error'
$Subject = if ($FailedSteps) { 'Onboarding job failed' } else { 'Onboarding job complete' }
$css = @'
body {
    background: #F6F6F6;
    font: 87.5%/1.5em Lato, sans-serif;
    padding: 20px
}

table {
    border-spacing: 1px;
    border-collapse: collapse;
    background: #F7F6F6;
    border-radius: 6px;
    overflow: hidden;
    max-width: 800px;
    width: 100%;
    margin: 0 auto;
    position: relative
}

td,
th {
    padding-left: 8px;
    text-align: left
}

thead tr {
    height: 60px;
    background: #367AB1;
    color: #F5F6FA;
    font-size: 1.2em;
    font-weight: 700;
    text-transform: uppercase
}

tbody tr {
    height: 48px;
    border-bottom: 1px solid #367AB1;
    text-transform: capitalize;
    font-size: 1em;

    &:last-child {
        border: 0;
    }

    tr:nth-child(even) {
        background-color: #E8E9E8
    }
}
'@

$html = html {
    head {
        style {
            $css
        }
    }
    Body {
        H1 { 'Onboarding job status' }

        ul {
            li { "Job ID: $($State.JobID)" }
            li { "Created: $($Job.CreatedTime)" }
            li { "Ticket ID: $($InputData.TicketNumber)" }
            li { "Status: $(if ($null -eq $State.FailedSteps) { 'Complete' } else { 'Failed' })" }
            li { a { 'View Job in Universal Automation' } -href ('https://{0}/admin/automation/jobs/{1}' -f $Job.ComputerName, $State.JobID) }
        }

        if ($FailedSteps) {
            h2 { 'Failed Steps' }
            ul {
                foreach ($Step in $FailedSteps) {
                    li { "$($Step.WorkerName) - $($Step.Error)" }
                }
            }
        }

        if ($Users.Count -gt 0) {
            h2 { 'Users' }

            Table {
                Thead {
                    tr {
                        Th { 'Name' }
                        Th { 'Display Name' }
                        Th { 'User Principal Name' }
                        Th { 'Created' }
                    }
                }

                Tbody {
                    foreach ($User in $Users) {
                        if ($null -eq $User.Created) {
                            $Created = Get-ADUser -Identity $User.SamAccountName -Properties Created | Select-Object -ExpandProperty Created
                        }
                        else {
                            $Created = $User.Created
                        }
                        tr {
                            td { $User.Name }
                            td { $User.DisplayName }
                            td { $User.UserPrincipalName }
                            td { $Created }
                        }
                    }
                }
            }
        }
    }
}

Send-IamNotification -Subject $Subject -ReplacementData @{} -HTMLBody $html