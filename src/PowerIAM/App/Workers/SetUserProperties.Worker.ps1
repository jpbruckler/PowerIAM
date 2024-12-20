param(
    $InputData,
    $State
)

$PSDefaultParameterValues = @{
    'Write-IamLog:WorkerName' = 'SetUserProperties'
}

# Loop through the created users in $State and set the properties
foreach ($User in $State.CommonData.UserObjects) {
    $InputData
}