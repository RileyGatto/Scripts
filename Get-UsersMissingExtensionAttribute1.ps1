# Finds users with extensionAttribute1 not set in on-prem AD and in Entra ID.
# Requires: ActiveDirectory module (RSAT) and Microsoft.Graph.Users module.

$stamp = Get-Date -Format "yyyyMMdd_HHmm"

# ---------- On-premises AD ----------
Import-Module ActiveDirectory

$adUsers = Get-ADUser -Filter 'extensionAttribute1 -notlike "*"' -Properties extensionAttribute1 |
    Select-Object Name, SamAccountName, UserPrincipalName, Enabled

$adUsers | Export-Csv ".\AD_NoExtensionAttribute1_$stamp.csv" -NoTypeInformation
Write-Host "AD users with extensionAttribute1 not set: $($adUsers.Count)"

# ---------- Entra ID ----------
Connect-MgGraph -Scopes "User.Read.All"

$entraUsers = Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, OnPremisesExtensionAttributes |
    Where-Object { -not $_.OnPremisesExtensionAttributes.ExtensionAttribute1 } |
    Select-Object DisplayName, UserPrincipalName, AccountEnabled

$entraUsers | Export-Csv ".\Entra_NoExtensionAttribute1_$stamp.csv" -NoTypeInformation
Write-Host "Entra users with extensionAttribute1 not set: $($entraUsers.Count)"
