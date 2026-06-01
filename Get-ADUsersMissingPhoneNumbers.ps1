# Get-ADUsersMissingPhoneNumbers.ps1
# Finds all enabled AD users who are:
#   - Missing a Telephone Number (General tab) and/or Mobile Phone (Telephones tab)
#   - Have the placeholder number 1300 176 077 in either field
# Exports a CSV report for review and correction.

#Requires -Module ActiveDirectory

$PlaceholderNumber = '1300 176 077'
$ReportPath = "$PSScriptRoot\AD_Users_Missing_Phone_Numbers_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"

Write-Host "Querying Active Directory for users with missing or placeholder phone numbers..." -ForegroundColor Cyan

$Users = Get-ADUser -Filter { Enabled -eq $true } `
    -Properties DisplayName, SamAccountName, EmailAddress,
                 telephoneNumber, mobile, Department, Title, DistinguishedName |
    Where-Object {
        [string]::IsNullOrWhiteSpace($_.telephoneNumber) -or
        [string]::IsNullOrWhiteSpace($_.mobile)         -or
        $_.telephoneNumber -eq $PlaceholderNumber        -or
        $_.mobile          -eq $PlaceholderNumber
    } |
    Select-Object `
        @{ N='Name';                    E={ $_.DisplayName } },
        @{ N='Telephone (General Tab)'; E={ $_.telephoneNumber } },
        @{ N='Mobile (Telephones Tab)'; E={ $_.mobile } },
        @{ N='Issue';                   E={
            $issues = @()
            if ([string]::IsNullOrWhiteSpace($_.telephoneNumber))  { $issues += 'Missing Telephone' }
            elseif ($_.telephoneNumber -eq $PlaceholderNumber)     { $issues += 'Placeholder Telephone (1300 176 077)' }
            if ([string]::IsNullOrWhiteSpace($_.mobile))           { $issues += 'Missing Mobile' }
            elseif ($_.mobile -eq $PlaceholderNumber)              { $issues += 'Placeholder Mobile (1300 176 077)' }
            $issues -join ' | '
        }}
    Sort-Object Name

if ($Users.Count -eq 0) {
    Write-Host "All enabled users have valid phone numbers. No report generated." -ForegroundColor Green
    exit
}

$Users | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Done. $($Users.Count) user(s) found." -ForegroundColor Green
Write-Host "Report saved to: $ReportPath" -ForegroundColor Yellow
Write-Host ""

# Summary breakdown
$MissingBoth        = ($Users | Where-Object { $_.'Issue' -like '*Missing Telephone*' -and $_.'Issue' -like '*Missing Mobile*' }).Count
$MissingTelOnly     = ($Users | Where-Object { $_.'Issue' -eq 'Missing Telephone' }).Count
$MissingMobOnly     = ($Users | Where-Object { $_.'Issue' -eq 'Missing Mobile' }).Count
$PlaceholderTel     = ($Users | Where-Object { $_.'Issue' -like '*Placeholder Telephone*' }).Count
$PlaceholderMob     = ($Users | Where-Object { $_.'Issue' -like '*Placeholder Mobile*' }).Count

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Missing both Telephone & Mobile     : $MissingBoth"
Write-Host "  Missing Telephone only              : $MissingTelOnly"
Write-Host "  Missing Mobile only                 : $MissingMobOnly"
Write-Host "  Placeholder number in Telephone     : $PlaceholderTel"
Write-Host "  Placeholder number in Mobile        : $PlaceholderMob"
