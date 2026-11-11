# Cedarbridge Health System — Enterprise Identity Security & Governance

**Microsoft Entra ID · GitHub Enterprise Managed Users · Zammad · OIDC/SAML · SCIM · PowerShell · Identity Governance**

> **An access change can be successful in the directory and still be incomplete in the application.** I encountered that during an employee transfer: Entra ID removed Jordan from the GitHub Developer group, but GitHub retained the entitlement until SCIM caught up. This lab follows access from approval and authentication through provisioning, review, removal, and final-state verification.

## The problem: Who still has access?

Cedarbridge Health System (CHS) is a **fictional healthcare organization** integrating three acquired clinics. Employees and contractors need controlled access to a clinical software integration project, while support staff need a secure way to handle access issues.

The CISO wanted answers to three questions:

- **Who approved access?** Developers, project leads, and contractors need different permissions and documented business justification.
- **Does access still match the job?** Transfers and contract endings can leave outdated entitlements behind.
- **Can we prove access was actually removed?** A completed review or directory update does not by itself demonstrate revocation inside a downstream application.

**My objective:** Build and test workforce SSO, least-privilege application access, time-limited administration, approval and recertification workflows, and evidence-based remediation—not merely configure features.

## What I built

| Requirement | Implementation | Verification |
| --- | --- | --- |
| Workforce SSO | GitHub Enterprise Managed Users via **OIDC**; Zammad support desk via **SAML 2.0** | Successful application sign-ins; Entra sign-in records for Zammad |
| Provisioning | Entra-to-GitHub **SCIM** users and groups | Provisioning events and GitHub team membership |
| Application RBAC | GitHub Developer (**Write**) and Project Lead (**Maintain**) teams; Zammad **Customer** and **Agent** roles | Repository permission checks and actual support-ticket workflow |
| Authentication controls | Entra Conditional Access, privileged-user phishing-resistant MFA policy, blocked legacy authentication; broader policies in Report-only | Policy configuration and relevant sign-in evaluations |
| Privileged access | PIM-eligible Cloud Application Administrator, tested just-in-time activation; emergency accounts | PIM and sign-in evidence |
| Access governance | Entitlement Management request/manager approval; GitHub Developer access review | Approval, denial, exported CSV, and reconciliation |
| Identity lifecycle | Controlled Developer → Project Lead mover using Microsoft Graph PowerShell | Group-state validation plus GitHub SCIM/audit evidence |

**[View the identity architecture](Architecture/CHS-Identity-Architecture.md)**

## Case study 1 — A contractor no longer needs access

**Person:** Taylor Morgan, temporary integration contractor  
**Entitlement:** `CHS-Integration-Developer-Access` / `SG-CHS-GH-Developers`

Taylor requested temporary GitHub Developer access. Daniel approved the entitlement request through an Entra access package. Later, Marcus reviewed the group and **denied Taylor's continued access** because the contractor assignment had ended. In the same review, Marcus approved Jordan's Developer access based on the business need **at that point in time**.

The exported review shows **one approval and one denial**, but both rows say **`Apply Result: Not applied`**. That is not evidence of automatic review enforcement. Taylor's access-package assignment was revoked separately; Jordan's Developer access was removed later as part of a different role-change event.

To reconcile decisions against actual application state, I checked the **All members** view in Entra and the GitHub `clinical-integration-developers` team linked to the IdP group. Both showed **zero members** at the final verification. This confirms the **current state** of the reviewed group/team; it does **not establish which operation removed each identity or that the review engine applied the decisions**.

**Evidence:** [Review decisions](Evidence/05-Access-Reviews/Access-Review-Individual-Results.png) · [Entra final group state](Evidence/05-Access-Reviews/UAR-Entra-Developer-Group-All-Members.png) · [GitHub team final state](Evidence/05-Access-Reviews/UAR-GitHub-Developer-Team-Final-State.png) · [CSV reconciliation](Evidence/05-Access-Reviews/CHS-UAR-Decision-Reconciliation.csv) · [Audit narrative](Documentation/CHS-UAR-Audit-Reconciliation.md)

**Lesson:** A reviewer decision, a remediation action, and proof of the resulting access state are three separate records.

## Case study 2 — A transfer leaves old access behind

**Person:** Jordan Lee  
**Request:** `CHS-MOV-001` — Developer → Project Lead

Jordan needed Project Lead **Maintain** permissions and no longer needed the Developer **Write** entitlement. I used simulated HR/manager approval records and Microsoft Graph PowerShell to validate the request, add/verify the new role, and remove the old Developer group membership while preserving unrelated access.

| Entra security group | Before | Verified final state |
| --- | --- | --- |
| `SG-CHS-GH-Developers` | Member | **Not a member** |
| `SG-CHS-GH-ProjectLeads` | Not a member | **Member** |
| `SG-CHS-CA-Pilot` | Member | Preserved |
| `SG-CHS-EmployeePortal-Users` | Member | Preserved |

The difficult part was downstream consistency. Entra reflected the removal first, while GitHub still showed Jordan as a Developer. After subsequent SCIM synchronization, GitHub audit events showed the old external-group/team membership removed. I correlated the PowerShell reports, directory state, and application-side events rather than calling the change complete after the first successful command.

**Evidence:** [Removal execution](Evidence/06-JML-Automation/JML-Developer-Removal-Execution.png) · [Final-state validation](Evidence/06-JML-Automation/JML-Mover-Final-State-Validation.png) · [GitHub removal audit](Evidence/06-JML-Automation/Jordan-GitHub-SCIM-Member-Removal.png)

**Lesson:** Reconciliation must extend beyond the identity provider and allow for asynchronous SCIM propagation.

## Case study 3 — Entra SSO does not equal administrator access

**Application:** CHS Clinic Integration Support Desk (Zammad)  
**Federation:** Microsoft Entra ID → Zammad via **SAML 2.0**

I configured a Zammad enterprise application in Entra using its SAML Entity ID and ACS callback URL, imported the Entra IdP signing certificate into Zammad, assigned test users, and verified Jordan's sign-in through Entra. The Entra sign-in log identified the correct CHS application and showed a successful event. Conditional Access evaluations were inspected separately; an application sign-in alone is **not proof** that MFA was enforced.

I then tested **application-local authorization**, which SAML authentication does not automatically grant:

| Test identity | Zammad role | Observed behavior |
| --- | --- | --- |
| Jordan | Customer | Could submit a ticket and view his own tickets; could not use agent ticket-management functions |
| Marcus | Agent | Could access the support group, take ownership of Jordan's ticket, and send a public response |
| Existing local administrator | Admin | Kept for administrative recovery during SSO testing |

**Test scenario:** Jordan reported an EHR integration portal access problem following his Developer → Project Lead transfer. Marcus accepted the ticket and responded with a plan to verify role memberships and downstream permissions. This was a **support workflow simulation**, not a live EHR access change.

An initial SSO attempt produced a one-off HTTP 422 anti-CSRF error. Retrying worked and later attempts reached Microsoft sign-in normally. The root cause was **not independently confirmed**.

**Evidence:** [Zammad SSO login option](Evidence/08-Zammad-SAML-RBAC/Zammad-CHS-Employee-SSO-Login.png) · [Jordan's initial Customer dashboard](Evidence/08-Zammad-SAML-RBAC/Zammad-Jordan-Customer-Initial-Dashboard.png) · [Marcus Agent group permission configuration](Evidence/08-Zammad-SAML-RBAC/Zammad-Marcus-Agent-Group-Permissions.png)

**Lesson:** Entra determines who can authenticate to the app through SAML; **Zammad still maintains its own Customer, Agent, and Admin permissions**. Those local roles need separate governance and periodic review.

## Supporting security controls

- **Conditional Access:** Pilot and privileged-user authentication policies were enabled; broader MFA and risk policies remained **Report-only**, not production-enforced. [Policy evidence](Evidence/01-Conditional-Access/CA-Policies-Overview.png)
- **PIM:** Tested time-limited activation of an eligible Cloud Application Administrator role. [PIM evidence](Evidence/02-Privileged-Access/PIM-CloudAppAdmin-Successful-Activation.png)
- **GitHub RBAC:** Set default repository permission to **None** and mapped Developer and Project Lead teams to **Write** and **Maintain**. [Repository permissions](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)
- **SAML fault test:** In a separate Microsoft Entra SAML Toolkit lab app, intentionally mismatched an ACS URL, reproduced `AADSTS50011`, restored it, and verified authentication. This was **not** the Zammad application. [Fault evidence](Evidence/07-SAML-Federation/SAML-ACS-Mismatch-AADSTS50011.png) · [Recovery evidence](Evidence/07-SAML-Federation/SAML-Authorized-SignIn.png)

## Automation and audit evidence

The existing `Automation/` folder contains **two PowerShell scripts**, synthetic HR/approval inputs, and sample execution/validation reports:

- `Remove-CHSDeveloper.ps1` — validates the simulated mover request, supports dry-run behavior, and requires explicit operator confirmation for removal.
- `CHS-TestMoverFinalState.ps1` — checks expected Entra memberships and runs simulated negative-request tests.

The published sanitized scripts have **not** been re-tested against the tenant, and they do **not** perform GitHub-side verification themselves. That verification was a separate manual audit step.

For access reviews, I exported a **sanitized Entra decision CSV** and built a **read-only decision-to-remediation reconciliation**. Neither scheduled CSV exports nor automated UAR enforcement were implemented in this lab. See the [UAR audit narrative](Documentation/CHS-UAR-Audit-Reconciliation.md) and [decision reconciliation CSV](Evidence/05-Access-Reviews/CHS-UAR-Decision-Reconciliation.csv).

## Findings and control limitations

| Finding | Actual status / next control |
| --- | --- |
| Review CSV shows `Not applied` | Decisions recorded; separately performed removals and final-state checks documented, **not** review auto-enforcement |
| Entra vs. GitHub propagation delay | Observed and resolved; ongoing drift monitoring not implemented |
| Zammad local Agent/Admin roles | Functionally tested; automatic recertification of local roles not implemented |
| Broader MFA / identity-risk policies | **Report-only**; no claim of enforced risk blocking |
| Original standing Global Administrator | Retained; privileged-access reduction remains an identified gap |
| GitHub SCIM provisioning credential | Integration tested; automated credential rotation not implemented |
| SAML signing certificate rollover (toolkit lab) | Replacement staged; successful rollover not demonstrated |
| JML automation | Mover scenario tested; full HRIS-driven joiner/leaver orchestration not implemented |

This is a **fictional healthcare lab**, not a production deployment, a HIPAA compliance attestation, or a certified security assessment. All examples use test identities and no patient data.

## Repository map

```text
Architecture/         Identity data flows and trust boundaries
Automation/           PowerShell scripts, synthetic inputs, sample reports
Demo/                 Demo assets and walkthrough materials
Documentation/        Standards, SOP, runbooks, control assessment, UAR reconciliation
Evidence/
  01-Conditional-Access/ ... 07-SAML-Federation/   Existing tests
  05-Access-Reviews/                              Export reconciliation and final-state checks
  08-Zammad-SAML-RBAC/                             SSO and application-role evidence
README.md             Project overview and linked case studies
```

**Tools:** Microsoft Entra ID P2, Microsoft Graph PowerShell, PowerShell 7, GitHub Enterprise Cloud (EMU), SCIM, OIDC, SAML 2.0, Zammad, Conditional Access, PIM, Entitlement Management, Access Reviews, FIDO2.

*Portfolio note: this repository presents tested outcomes and explicitly separates observed configuration, reviewer decisions, manual remediation, and proposed improvements.*
