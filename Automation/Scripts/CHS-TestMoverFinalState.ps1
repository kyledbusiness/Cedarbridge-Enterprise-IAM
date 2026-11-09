# Cedarbridge Health System - Final Mover state validation (laboratory example)
# READ ONLY against Microsoft Entra ID; exports local CSV reports.
# GitHub state must be verified separately.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][guid]$TenantId,
    [Parameter(Mandatory = $true)][string]$ExpectedUserPrincipalName,
    [string]$ExpectedRequestId = 'CHS-MOV-001',
    [string]$ExpectedApprover = 'Daniel Kim',
    [string]$ExpectedApprovalReference = 'LAB-SIMULATED-APPROVAL-001',
    [string]$InputDirectory,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$automationDir = Split-Path -Parent $PSScriptRoot
if (-not $InputDirectory) { $InputDirectory = Join-Path $automationDir 'Sample-Inputs' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $automationDir 'Output' }

function Test-SimulatedApproval {
    param($Transfer, $Approval)
    return (
        $Transfer.RequestId -ceq $ExpectedRequestId -and
        $Transfer.UserPrincipalName -ieq $ExpectedUserPrincipalName -and
        $Transfer.ChangeType -ceq 'Mover' -and
        $Transfer.FromRole -ceq 'Developer' -and
        $Transfer.ToRole -ceq 'ProjectLead' -and
        $Approval.RequestId -ceq $Transfer.RequestId -and
        $Approval.Approver -ceq $ExpectedApprover -and
        $Approval.Decision -ceq 'Approved' -and
        $Approval.ApprovalReference -ceq $ExpectedApprovalReference
    )
}

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
    throw 'Expected exactly one transfer and one approval record.'
}
$t = $transfers[0]
$a = $approvals[0]
if (-not (Test-SimulatedApproval -Transfer $t -Approval $a)) {
    throw 'Simulated request/approval validation failed.'
}
$effectiveDate = [datetime]::ParseExact(
    $t.EffectiveDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture
)
if ($effectiveDate.Date -gt (Get-Date).Date) {
    throw 'Transfer is not yet effective.'
}

$exceptionTests = @(
    [pscustomobject]@{
        Test = 'Denied simulated approval'
        Rejected = (-not (Test-SimulatedApproval -Transfer $t -Approval ([pscustomobject]@{
            RequestId = $a.RequestId; Approver = $a.Approver
            Decision = 'Denied'; ApprovalReference = $a.ApprovalReference
        })))
    }
    [pscustomobject]@{
        Test = 'Unauthorized target role'
        Rejected = (-not (Test-SimulatedApproval -Transfer ([pscustomobject]@{
            RequestId = $t.RequestId; UserPrincipalName = $t.UserPrincipalName
            ChangeType = $t.ChangeType; FromRole = $t.FromRole
            ToRole = 'GlobalAdministrator'; EffectiveDate = $t.EffectiveDate
        }) -Approval $a))
    }
)
if (@($exceptionTests | Where-Object { -not $_.Rejected }).Count -gt 0) {
    throw 'In-memory negative-test validation failed.'
}

$ctx = Get-MgContext
if (-not $ctx -or [string]$ctx.TenantId -ne [string]$TenantId) {
    throw 'Connect to Microsoft Graph in the explicitly specified tenant.'
}
foreach ($scope in @('User.Read.All', 'Group.Read.All', 'GroupMember.Read.All')) {
    if ($scope -notin @($ctx.Scopes) -and -not ($scope -eq 'GroupMember.Read.All' -and 'GroupMember.ReadWrite.All' -in @($ctx.Scopes))) {
        throw "Graph connection is missing the delegated scope: $scope"
    }
}
$user = Get-MgUser -UserId $t.UserPrincipalName -ErrorAction Stop
$desired = [ordered]@{
    'SG-CHS-CA-Pilot'              = $true
    'SG-CHS-GH-Developers'         = $false
    'SG-CHS-GH-ProjectLeads'       = $true
    'SG-CHS-EmployeePortal-Users'  = $true
}
$timestamp = (Get-Date).ToString('o')
$state = @(
    foreach ($name in $desired.Keys) {
        $matches = @(Get-MgGroup -Filter "displayName eq '$name'" -ErrorAction Stop)
        if ($matches.Count -ne 1) { throw "Expected exactly one group named $name." }
        $ids = @(Get-MgGroupMember -GroupId $matches[0].Id -All -ErrorAction Stop | ForEach-Object { $_.Id })
        $actual = $user.Id -in $ids
        $expected = [bool]$desired[$name]
        [pscustomobject]@{
            Timestamp      = $timestamp
            RequestId      = $t.RequestId
            User           = $t.UserPrincipalName
            Group          = $name
            ExpectedMember = $expected
            ActualMember   = $actual
            Result         = if ($actual -eq $expected) { 'MATCH' } else { 'DRIFT' }
        }
    }
)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$state | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'CHS-Mover-Final-State.csv') -NoTypeInformation
$exceptionTests | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'CHS-Mover-Exception-Tests.csv') -NoTypeInformation

Write-Host "`n=== ENTRA DESIRED-STATE VERIFICATION ==="
$state | Format-Table Group, ExpectedMember, ActualMember, Result -AutoSize
Write-Host "`n=== SIMULATED NEGATIVE TESTS ==="
$exceptionTests | Format-Table -AutoSize
if (@($state | Where-Object { $_.Result -eq 'DRIFT' }).Count -gt 0) {
    Write-Warning 'Entra access drift detected; no directory changes were made.'
} else {
    Write-Host 'PASS: All checked Entra memberships match the expected state.'
}
Write-Host 'GitHub membership and authorization must be verified separately.'
Write-Host "Reports saved to: $OutputDirectory"
