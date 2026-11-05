<#
.SYNOPSIS
    Lists every member of each Entra ID group starting with DSP_ or DST_.
    Empty groups are included with a "(no members)" row so nothing is missed.

.REQUIREMENTS
    Microsoft Graph PowerShell SDK:
        Install-Module Microsoft.Graph -Scope CurrentUser
    Permissions: Group.Read.All, GroupMember.Read.All, User.Read.All
#>

$Prefixes   = @('DSP_', 'DST_')
$ExportPath = ".\DSP_DST_Group_Members_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

# Connect to Microsoft Graph (read-only scopes)
Connect-MgGraph -Scopes 'Group.Read.All', 'GroupMember.Read.All', 'User.Read.All' -NoWelcome

# Get all groups for each prefix
$Groups = foreach ($Prefix in $Prefixes) {
    Get-MgGroup -Filter "startswith(displayName,'$Prefix')" -All -Property Id, DisplayName
}

# startswith is not case-sensitive, so confirm the exact prefix and remove any duplicates
$Groups = $Groups |
    Where-Object { $_.DisplayName -cmatch '^(DSP_|DST_)' } |
    Sort-Object Id -Unique |
    Sort-Object DisplayName

Write-Host "Found $($Groups.Count) DSP_/DST_ groups. Getting members..." -ForegroundColor Cyan

$Results = foreach ($Group in $Groups) {
    Write-Host "  $($Group.DisplayName)"
    $Members = Get-MgGroupMember -GroupId $Group.Id -All -ErrorAction SilentlyContinue

    if (-not $Members) {
        [PSCustomObject]@{
            GroupName         = $Group.DisplayName
            MemberName        = '(no members)'
            UserPrincipalName = ''
            Email             = ''
            JobTitle          = ''
            Department        = ''
            MemberType        = ''
        }
        continue
    }

    foreach ($Member in $Members) {
        $Props = $Member.AdditionalProperties
        [PSCustomObject]@{
            GroupName         = $Group.DisplayName
            MemberName        = $Props['displayName']
            UserPrincipalName = $Props['userPrincipalName']
            Email             = $Props['mail']
            JobTitle          = $Props['jobTitle']
            Department        = $Props['department']
            # e.g. #microsoft.graph.user -> user, #microsoft.graph.group -> group
            MemberType        = ($Props['@odata.type'] -replace '#microsoft.graph.', '')
        }
    }
}

$Results | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host "Done. $($Results.Count) row(s) exported to $ExportPath" -ForegroundColor Green

# Quick on-screen summary: member count per group
$Results |
    Group-Object GroupName |
    Select-Object @{ n = 'GroupName';   e = { $_.Name } },
                  @{ n = 'MemberCount'; e = { ($_.Group | Where-Object MemberName -ne '(no members)').Count } } |
    Format-Table -AutoSize

Disconnect-MgGraph | Out-Null
