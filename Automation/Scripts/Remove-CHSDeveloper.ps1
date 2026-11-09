# Cedarbridge Health System - Developer group removal (laboratory example)
# CAUTION: This script can remove direct Entra group membership when -Execute is supplied.
# Simulated CSV approval is NOT independent approval verification.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][guid]$TenantId,
    [Parameter(Mandatory = $true)][string]$ExpectedUserPrincipalName,
    [string]$ExpectedRequestId = 'CHS-MOV-001',
    [string]$ExpectedApprover = 'Daniel Kim',
    [string]$ExpectedApprovalReference = 'LAB-SIMULATED-APPROVAL-001',
    [string]$InputDirectory,
    [string]$OutputDirectory,
    [switch]$GitHubProjectLeadVerified,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$automationDir = Split-Path -Parent $PSScriptRoot
if (-not $InputDirectory) { $InputDirectory = Join-Path $automationDir 'Sample-Inputs' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $automationDir 'Output' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$reportPath = Join-Path $OutputDirectory 'CHS-Mover-Removal.csv'

$report = [ordered]@{
    RequestId      = $ExpectedRequestId
    User           = $ExpectedUserPrincipalName
    Action         = 'REMOVE_DEVELOPER_ACCESS'
    ApprovalSource = 'SIMULATED_CSV'
    Status         = 'FAILED'
    Verified       = $false
    Timestamp      = (Get-Date).ToString('o')
}

try {
    $transferPath = Join-Path $InputDirectory 'HR-Transfers.csv'
    $approvalPath = Join-Path $InputDirectory 'HR-Approvals.csv'
    foreach ($path in @($transferPath, $approvalPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required CSV not found: $path"
        }
    }

    $transfers = @(Import-Csv -LiteralPath $transferPath)
    $approvals = @(Import-Csv -LiteralPath $approvalPath)
    if ($transfers.Count -ne 1 -or $approvals.Count -ne 1) {
        throw 'Expected exactly one transfer and one simulated approval record.'
    }
    $t = $transfers[0]
    $a = $approvals[0]
    if (
        $t.RequestId -cne $ExpectedRequestId -or
        $t.UserPrincipalName -ine $ExpectedUserPrincipalName -or
        $t.ChangeType -cne 'Mover' -or
        $t.FromRole -cne 'Developer' -or
        $t.ToRole -cne 'ProjectLead' -or
        $a.RequestId -cne $t.RequestId -or
        $a.Approver -cne $ExpectedApprover -or
        $a.Decision -cne 'Approved' -or
        $a.ApprovalReference -cne $ExpectedApprovalReference
    ) {
        throw 'Simulated request/approval data did not match expected values. No changes made.'
    }

    $effectiveDate = [datetime]::ParseExact(
        $t.EffectiveDate, 'yyyy-MM-dd',
        [Globalization.CultureInfo]::InvariantCulture
    )
    if ($effectiveDate.Date -gt (Get-Date).Date) {
        throw 'Transfer is not yet effective. No changes made.'
    }

    $ctx = Get-MgContext
    if (-not $ctx -or [string]$ctx.TenantId -ne [string]$TenantId) {
        throw 'Connect to Microsoft Graph in the explicitly specified tenant.'
    }
    foreach ($scope in @('User.Read.All', 'Group.Read.All', 'GroupMember.ReadWrite.All')) {
        if ($scope -notin @($ctx.Scopes)) {
            throw "Graph connection is missing the delegated scope: $scope"
        }
    }

    $user = Get-MgUser -UserId $t.UserPrincipalName -ErrorAction Stop
    $leadGroups = @(Get-MgGroup -Filter "displayName eq 'SG-CHS-GH-ProjectLeads'" -ErrorAction Stop)
    $devGroups = @(Get-MgGroup -Filter "displayName eq 'SG-CHS-GH-Developers'" -ErrorAction Stop)
    if ($leadGroups.Count -ne 1 -or $devGroups.Count -ne 1) {
        throw 'Expected one exact match for each role group. No changes made.'
    }
    $lead = $leadGroups[0]
    $dev = $devGroups[0]
    if (-not $lead.SecurityEnabled -or -not $dev.SecurityEnabled) {
        throw 'Unexpected group type. No changes made.'
    }
    if ('DynamicMembership' -in @($dev.GroupTypes)) {
        throw 'The Developer group is dynamic and cannot be directly modified.'
    }

    $leadIds = @(Get-MgGroupMember -GroupId $lead.Id -All -ErrorAction Stop | ForEach-Object { $_.Id })
    $devIds = @(Get-MgGroupMember -GroupId $dev.Id -All -ErrorAction Stop | ForEach-Object { $_.Id })
    if ($user.Id -notin $leadIds) {
        throw 'HOLD: The target Project Lead group membership is not present in Entra.'
    }

    if ($user.Id -notin $devIds) {
        $report.Status = 'ALREADY_REMOVED'
    } elseif (-not $Execute) {
        $report.Status = 'DRY_RUN'
        Write-Host 'DRY RUN: Developer group removal would be attempted; no changes made.'
    } else {
        # This is a human attestation, NOT an automated GitHub permission check.
        if (-not $GitHubProjectLeadVerified) {
            throw 'HOLD: Confirm GitHub Project Lead access separately, then supply -GitHubProjectLeadVerified.'
        }
        Write-Host "Identity: $($t.UserPrincipalName)"
        Write-Host "REMOVE: $($dev.DisplayName) | RETAIN: $($lead.DisplayName)"
        $expectedConfirmation = "REMOVE-$ExpectedRequestId"
        $answer = Read-Host "Type $expectedConfirmation to confirm removal"
        if ($answer -cne $expectedConfirmation) {
            $report.Status = 'CANCELLED'
            throw 'Operator cancelled. No changes made.'
        }
        Remove-MgGroupMemberByRef -GroupId $dev.Id -DirectoryObjectId $user.Id -ErrorAction Stop
        $report.Status = 'REMOVED'
    }

    $leadAfter = @(Get-MgGroupMember -GroupId $lead.Id -All -ErrorAction Stop | ForEach-Object { $_.Id })
    $devAfter = @(Get-MgGroupMember -GroupId $dev.Id -All -ErrorAction Stop | ForEach-Object { $_.Id })
    $report.Verified = ($user.Id -in $leadAfter -and $user.Id -notin $devAfter)
    if ($Execute -and -not $report.Verified) {
        $report.Status = 'VERIFICATION_FAILED'
        throw 'Post-change Entra membership verification failed.'
    }
    if (-not $Execute -and $report.Status -eq 'DRY_RUN') {
        # Verification is false for the desired final state until removal actually occurs.
        $report.Verified = $false
    }
} catch {
    if ($report.Status -eq 'FAILED') { Write-Warning 'Precondition or API operation failed; review the error before retrying.' }
    throw
} finally {
    $report.Timestamp = (Get-Date).ToString('o')
    [pscustomobject]$report | Export-Csv -LiteralPath $reportPath -NoTypeInformation
    [pscustomobject]$report | Format-List
    Write-Host "Run report: $reportPath"
}

if ($Execute -and $report.Verified) {
    Write-Host 'Entra Developer removal verified. Verify final GitHub state independently.'
}
