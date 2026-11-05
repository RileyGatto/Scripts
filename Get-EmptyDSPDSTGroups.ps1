<#
.SYNOPSIS
    Lists all Entra ID groups starting with DSP_ or DST_ that have no members.

.REQUIREMENTS
    Microsoft Graph PowerShell SDK:
        Install-Module Microsoft.Graph -Scope CurrentUser
    Permissions: Group.Read.All, GroupMember.Read.All
#>

$Prefixes   = @('DSP_', 'DST_')
$ExportPath = ".\Empty_DSP_DST_Groups_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

# Connect to Microsoft Graph (read-only scopes)
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All' -NoWelcome

# Get all groups for each prefix
$Groups = foreach ($Prefix in $Prefixes) {
    Get-MgGroup -Filter "startswith(displayName,'$Prefix')" -All `
        -Property Id, DisplayName, Description, GroupTypes, MailEnabled, SecurityEnabled
}

# startswith is not case-sensitive, so confirm the exact prefix and remove any duplicates
$Groups = $Groups |
    Where-Object { $_.DisplayName -cmatch '^(DSP_|DST_)' } |
    Sort-Object Id -Unique

Write-Host "Found $($Groups.Count) DSP_/DST_ groups. Checking membership..." -ForegroundColor Cyan

$EmptyGroups = foreach ($Group in $Groups) {
    # Only need to know whether at least one member exists
    $Member = Get-MgGroupMember -GroupId $Group.Id -Top 1 -ErrorAction SilentlyContinue

    if (-not $Member) {
        [PSCustomObject]@{
            GroupName   = $Group.DisplayName
            GroupId     = $Group.Id
            Description = $Group.Description
            GroupType   = if ($Group.GroupTypes -contains 'Unified') { 'Microsoft 365' }
                          elseif ($Group.SecurityEnabled) { 'Security' }
                          else { 'Distribution' }
            IsDynamic   = $Group.GroupTypes -contains 'DynamicMembership'
        }
    }
}

$EmptyGroups = $EmptyGroups | Sort-Object GroupName

if ($EmptyGroups) {
    $EmptyGroups | Format-Table GroupName, GroupType, IsDynamic -AutoSize
    $EmptyGroups | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Host "$($EmptyGroups.Count) empty group(s) found. Exported to $ExportPath" -ForegroundColor Green
}
else {
    Write-Host 'No empty DSP_/DST_ groups found.' -ForegroundColor Green
}

Disconnect-MgGraph | Out-Null
