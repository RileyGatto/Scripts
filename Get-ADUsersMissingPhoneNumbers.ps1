
$CustomerServiceGroup  = 'Customer Service Officers'
$CustomerServiceNumber = '1300 176 077'
$PlaceholderNumbers = @(
    '02 6962 8300',
    '02 6962 8228',
    '02 6962 8400'
)

$ExcludedNames = @(
    'Adroit Creations',
    'Adroit Test',
    'Advanced Comm User',
    'auth',
    'auth backup',
    'BitTitan MigrationWiz',
    'Building Inspection iPad',
    'CBIS International',
    'CIBIS User',
    'City Strategy Temp Account 1',
    'Civica',
    'CM Services',
    'CSO Tasks',
    'Datascape API',
    'Datascape Sync',
    'Development Administration',
    'Development Engineer iPad',
    'Drainage Diagrams Officer',
    'ePlanning Vetting',
    'eservices'
)

# Where Report is stored
$ReportPath = "$PSScriptRoot\Reports\PhoneAudit_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"

# Import modules so you dont have to
Import-Module ActiveDirectory       -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop

# Used to get data from Entra
Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome -ErrorAction Stop

# Customer Serivce Officers
$CSSids = @{}
Get-ADGroupMember -Identity $CustomerServiceGroup -Recursive |
    Where-Object { $_.objectClass -eq 'user' } |
    ForEach-Object { $CSSids[$_.SID.Value] = $true }

# Issue colume value
function Get-Issues ($tel, $mob, $isCS) {
    $i = @()
    if ($tel -eq $CustomerServiceNumber -and -not $isCS) { $i += 'Unauthorised 1300 (Telephone)' }
    if ($mob -eq $CustomerServiceNumber -and -not $isCS) { $i += 'Unauthorised 1300 (Mobile)' }
    foreach ($p in $PlaceholderNumbers) {
        if ($tel -eq $p) { $i += "Placeholder Telephone ($tel)" }
        if ($mob -eq $p) { $i += "Placeholder Mobile ($mob)" }
    }
    if ($tel -eq '' -and $mob -eq '') { $i += 'Missing both Telephone and Mobile' }
    return $i
}

$Results = @()

# AD users
Get-ADUser -Filter { Enabled -eq $true } -Properties DisplayName, Title, telephoneNumber, mobile, ObjectSID |
Where-Object { $ExcludedNames -notcontains $_.DisplayName } |
ForEach-Object {
    $tel    = ([string]$_.telephoneNumber).Trim()
    $mob    = ([string]$_.mobile).Trim()
    $issues = Get-Issues $tel $mob $CSSids.ContainsKey($_.ObjectSID.Value)
    if ($issues.Count -eq 0) { return }
    $Results += [PSCustomObject]@{ Name = $_.DisplayName; Source = 'AD'; Title = $_.Title; Telephone = $tel; Mobile = $mob; Issue = $issues -join '; ' }
}

# Entra cloud-only users
Get-MgUser -All -Filter 'accountEnabled eq true' -Property Id, DisplayName, JobTitle, BusinessPhones, MobilePhone, OnPremisesSyncEnabled |
Where-Object { $_.OnPremisesSyncEnabled -ne $true -and $ExcludedNames -notcontains $_.DisplayName } |
ForEach-Object {
    $tel    = if ($_.BusinessPhones.Count -gt 0) { $_.BusinessPhones[0].Trim() } else { '' }
    $mob    = ([string]$_.MobilePhone).Trim()
    $issues = Get-Issues $tel $mob $false
    if ($issues.Count -eq 0) { return }
    $Results += [PSCustomObject]@{ Name = $_.DisplayName; Source = 'Entra'; Title = $_.JobTitle; Telephone = $tel; Mobile = $mob; Issue = $issues -join '; ' }
}

$Sorted = $Results |
    Sort-Object @{
        Expression = {
            if ($_.Issue -like '*Unauthorised 1300*') { 1 }
            elseif ($_.Issue -like '*Placeholder*')   { 2 }
            else                                      { 3 }
        }
    }, Name |
    Select-Object Name, Source, Title, Telephone, Mobile, Issue

if ($Sorted.Count -eq 0) { Write-Host 'No issues found.' -ForegroundColor Green; exit }

New-Item -ItemType Directory -Path "$PSScriptRoot\Reports" -Force | Out-Null
$Sorted | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

Write-Host "Report: $ReportPath" -ForegroundColor Yellow
Write-Host ''
Write-Host 'Summary:' -ForegroundColor Cyan
Write-Host "  Total flagged          : $($Sorted.Count)"
Write-Host "  AD users               : $(($Sorted | Where-Object { $_.Source -eq 'AD' }).Count)"
Write-Host "  Entra cloud-only       : $(($Sorted | Where-Object { $_.Source -eq 'Entra' }).Count)"
Write-Host "  Unauthorised 1300      : $(($Sorted | Where-Object { $_.Issue -like '*Unauthorised 1300*' }).Count)"
Write-Host "  Placeholder number     : $(($Sorted | Where-Object { $_.Issue -like '*Placeholder*' }).Count)"
Write-Host "  Missing Tel and Mobile : $(($Sorted | Where-Object { $_.Issue -like '*Missing both*' }).Count)"
