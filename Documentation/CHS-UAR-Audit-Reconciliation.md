# CHS — GitHub Developer Access Review: Decision & Remediation Reconciliation

**Scope:** November 2026 review of `SG-CHS-GH-Developers` for Cedarbridge Health System (fictional).  
**Reviewer:** Marcus Reid (test identity).  
**Source:** Sanitized Entra access-review export supplied by the lab owner, and separately captured current-state screenshots.

## Finding

The Entra access review recorded **two decisions (one Approve, one Deny)**. In the sanitized export both are **`Not applied`**. The review was still shown as **Active** when inspected. Therefore the record supports **completed reviewer decisions**, but not automatically applied decisions.

| User | Decision and justification | What happened separately | Verified current state |
| --- | --- | --- | --- |
| Jordan Lee | **Approve** — developer access justified at review time | Later moved Developer → Project Lead through a separate JML procedure; former Developer membership removed | Entra group and GitHub Developer team both show zero total membership at final check; prior mover report additionally checked Jordan's individual membership |
| Taylor Morgan | **Deny** — contractor's assignment ended | Access-package assignment revoked separately; group/team current state was then checked | Entra group **All members: 0**; GitHub `clinical-integration-developers` **0 members**. Taylor cannot be in either at the captured point in time |

## Evidence chain

1. [Original review decision screenshot](../Evidence/05-Access-Reviews/Access-Review-Individual-Results.png) — decisions and reviewer attribution.
2. [Normalized decision reconciliation CSV](../Evidence/05-Access-Reviews/CHS-UAR-Decision-Reconciliation.csv) — manually prepared working report derived from the sanitized export.
3. [Entra Developer group, All members](../Evidence/05-Access-Reviews/UAR-Entra-Developer-Group-All-Members.png) — zero members after refresh.
4. [GitHub Developer team](../Evidence/05-Access-Reviews/UAR-GitHub-Developer-Team-Final-State.png) — zero members; team linked to `SG-CHS-GH-Developers` IdP group.
5. [Jordan's mover final-state validation](../Evidence/06-JML-Automation/JML-Mover-Final-State-Validation.png) and [GitHub audit](../Evidence/06-JML-Automation/Jordan-GitHub-SCIM-Member-Removal.png) — separate lifecycle evidence.

## Audit interpretation

**What this proves:** The specified review recorded decisions; the Entra group and GitHub team had no remaining members at the time of their respective snapshots; Jordan's mover has an independent evidence trail.

**What this does not prove:** That the review engine auto-applied its decisions, when Taylor's specific membership was removed, or that the review itself caused the downstream change. An empty team is current-state evidence, not a timestamped removal event. For a production audit, preserve original review IDs, sign-in/audit logs, approver records, removal events, timestamps, and traceability to change tickets.

## Sanitization and reporting notes

The input sanitized CSV used inconsistent placeholders for `AccessReviewId`, `ReviewerID`, and `AppliedByUserId`. Rather than misrepresent them as original Entra identifiers, this derivative CSV **omits those fields** and uses one descriptive case reference. The unmodified original export should remain private. The derivative report is **manually assembled, not a scheduled or automatic Graph export**.

**Potential follow-on:** A read-only Microsoft Graph PowerShell task to export review decisions to a timestamped CSV, with separate reconciliations to group and application entitlements. This is proposed, not deployed.
