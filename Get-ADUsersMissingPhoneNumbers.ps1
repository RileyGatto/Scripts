# =============================================================================
# CONFIGURATION
# =============================================================================
$CSGroup      = 'Customer Service Officers'
$CS1300       = '1300 176 077'
$Placeholders = @('02 6962 8300', '02 6962 8228', '02 6962 8400')
$ReportPath = "$PSScriptRoot\Reports\PhoneAudit_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"
# =============================================================================

Import-Module ActiveDirectory       -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome -ErrorAction Stop

# Get Customer Service members from AD
$CSSids = @{}
Get-ADGroupMember -Identity $CSGroup -Recursive |
    Where-Object { $_.objectClass -eq 'user' } |
    ForEach-Object { $CSSids[$_.SID.Value] = $true }

$Results = @()

# --- AD users ---
Get-ADUser -Filter { Enabled -eq $true } -Properties DisplayName, Title, telephoneNumber, mobile, ObjectSID |
ForEach-Object {
    $tel   = ([string]$_.telephoneNumber).Trim()
    $mob   = ([string]$_.mobile).Trim()
    $isCS  = $CSSids.ContainsKey($_.ObjectSID.Value)
    $issue = @()

    if ($tel -eq $CS1300 -and -not $isCS)  { $issue += 'Unauthorised 1300 (Telephone)' }
    if ($mob -eq $CS1300 -and -not $isCS)  { $issue += 'Unauthorised 1300 (Mobile)' }
    foreach ($p in $Placeholders) {
        if ($tel -eq $p) { $issue += "Placeholder Telephone ($tel)" }
        if ($mob -eq $p) { $issue += "Placeholder Mobile ($mob)" }
    }
    if ($tel -eq '' -and $mob -eq '') { $issue += 'Missing both Telephone and Mobile' }

    if ($issue.Count -eq 0) { return }
    $Results += [PSCustomObject]@{
        Name      = $_.DisplayName
        Source    = 'AD'
        Title     = $_.Title
        Telephone = $tel
        Mobile    = $mob
        Issue     = $issue -join '; '
    }
}

# --- Entra cloud-only users ---
Get-MgUser -All -Filter 'accountEnabled eq true' -Property Id, DisplayName, JobTitle, BusinessPhones, MobilePhone, OnPremisesSyncEnabled |
Where-Object { $_.OnPremisesSyncEnabled -ne $true } |
ForEach-Object {
    $tel   = if ($_.BusinessPhones.Count -gt 0) { $_.BusinessPhones[0].Trim() } else { '' }
    $mob   = ([string]$_.MobilePhone).Trim()
    $issue = @()

    if ($tel -eq $CS1300)  { $issue += 'Unauthorised 1300 (Telephone)' }
    if ($mob -eq $CS1300)  { $issue += 'Unauthorised 1300 (Mobile)' }
    foreach ($p in $Placeholders) {
        if ($tel -eq $p) { $issue += "Placeholder Telephone ($tel)" }
        if ($mob -eq $p) { $issue += "Placeholder Mobile ($mob)" }
    }
    if ($tel -eq '' -and $mob -eq '') { $issue += 'Missing both Telephone and Mobile' }

    if ($issue.Count -eq 0) { return }
    $Results += [PSCustomObject]@{
        Name      = $_.DisplayName
        Source    = 'Entra'
        Title     = $_.JobTitle
        Telephone = $tel
        Mobile    = $mob
        Issue     = $issue -join '; '
    }
}

# Sort: 1300 first, then placeholders, then missing
$Sorted = $Results | Sort-Object @{
    Expression = {
        if ($_.Issue -like '*Unauthorised 1300*') { 1 }
        elseif ($_.Issue -like '*Placeholder*')   { 2 }
        else                                      { 3 }
    }
}, Name

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
