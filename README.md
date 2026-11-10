# Cedarbridge Health System | Enterprise Identity Security & Governance

**Microsoft Entra ID · GitHub Enterprise Managed Users · OIDC/SAML · SCIM · PowerShell · Identity Governance**

> **A successful directory change does not necessarily mean application access has changed.**
>
> I learned this while moving an employee from a GitHub Developer role to Project Lead: Entra ID showed the old membership was removed, but GitHub retained it until SCIM synchronization completed. This project documents how I built the identity controls, investigated that gap, and verified the final access state.

## The Scenario

Cedarbridge Health System (CHS) is a **fictional healthcare organization** integrating three acquired clinics. It needs consistent authentication, controlled privileged access, approved access requests, and reliable provisioning for a clinical software integration team. Temporary access must be reviewed and removed when no longer justified.

I built a hands-on lab to answer one question:

**How can IAM prove that the right people have the right access—and that access really disappears when it should?**

## What I Implemented

| Area | Implementation |
| --- | --- |
| **Authentication** | Entra Conditional Access: pilot MFA, phishing-resistant MFA policy for privileged accounts, and legacy-authentication blocking. Broader MFA and risk policies remain Report-only. |
| **Privileged access** | PIM-eligible Cloud Application Administrator role, time-limited activation, and two tested emergency administrator sign-ins. |
| **Federation** | GitHub Enterprise Managed Users via OIDC; simulated Employee Operations Portal via SAML 2.0. |
| **Provisioning & RBAC** | Entra-to-GitHub SCIM synchronization; mapped GitHub Developer and Project Lead teams to Write and Maintain repository permissions. Default repository permission: None. |
| **Identity governance** | Entitlement Management request/manager approval and a completed access review (one approval, one denial). Denied access was separately revoked and downstream deprovisioning checked. |
| **Lifecycle automation** | Microsoft Graph PowerShell validation and removal for a Developer → Project Lead mover scenario, with CSV evidence and final-state checks. |
| **Control assessment** | Documented MFA scope, standing administrator privilege, SCIM credential management, certificate rollover, monitoring, and synchronization gaps. |

### Identity Flow

```text
Workforce users / administrators
             |
             v
    Microsoft Entra ID
    | Conditional Access / MFA / PIM
    | Entitlement Management / Access Reviews
    |
    +-- OIDC SSO ------------------> GitHub Enterprise Managed Users
    |                                 ^
    +-- SCIM users & groups ----------+--> GitHub teams --> Repository RBAC
    |
    +-- SAML SSO ------------------> Employee Operations Portal (lab)
    |
Simulated HR change + approval CSVs
             |
             v
     Microsoft Graph PowerShell --> Entra group changes
                                        |
                             Verify Entra + GitHub outcomes
```

*The final visual architecture diagram will be updated after the remaining lab enhancements.*

## Featured Case Study: Jordan's Role Change

**Request:** `CHS-MOV-001`  
**Mover:** Developer → Project Lead  
**Approval source:** Simulated HR/manager CSV records

I captured Jordan's starting memberships, planned the add–verify–remove sequence, confirmed the target Project Lead access, removed the obsolete Developer group membership, and then checked both Entra and GitHub.

| Entitlement | Before | Verified final Entra state |
| --- | --- | --- |
| `SG-CHS-GH-Developers` | Member | Not a member |
| `SG-CHS-GH-ProjectLeads` | Not a member | Member |
| `SG-CHS-CA-Pilot` | Member | Member (preserved) |
| `SG-CHS-EmployeePortal-Users` | Member | Member (preserved) |

**Result:** All four checked Entra memberships matched the intended state. Simulated negative tests rejected a denied approval and an unauthorized target role. GitHub audit events separately confirmed removal from the Developer external group and team following synchronization.

**The operational lesson:** An Entra group-removal response is not sufficient evidence of downstream revocation. I correlated PowerShell reports, Entra events, SCIM activity, and GitHub audit events before treating the change as complete.

**Evidence:**

- [Removal execution](Evidence/06-JML-Automation/JML-Developer-Removal-Execution.png)
- [Final-state validation](Evidence/06-JML-Automation/JML-Mover-Final-State-Validation.png)
- [GitHub removal audit](Evidence/06-JML-Automation/Jordan-GitHub-SCIM-Member-Removal.png)

## Other Verified Tests

### Entitlement Management

A manager approved a request for temporary GitHub access.

[View approval result](Evidence/04-Entitlement-Management/Access-Package-Approval-Success.png)

### User Access Reviews

Marcus approved Jordan's access and denied Taylor's. The access package was revoked separately.

[View review decisions](Evidence/05-Access-Reviews/Access-Review-Individual-Results.png)

### SAML Troubleshooting

I deliberately misconfigured the Assertion Consumer Service (ACS) URL, reproduced `AADSTS50011`, restored the setting, and verified sign-in.

- [Authentication failure](Evidence/07-SAML-Federation/SAML-ACS-Mismatch-AADSTS50011.png)
- [Successful authentication](Evidence/07-SAML-Federation/SAML-Authorized-SignIn.png)

### Privileged Identity Management

Verified a time-limited administrative role activation.

[View active assignment](Evidence/02-Privileged-Access/PIM-CloudAppAdmin-Successful-Activation.png)

### SCIM Provisioning and RBAC

Verified a completed provisioning cycle and GitHub team repository permissions.

- [SCIM provisioning overview](Evidence/03-OIDC-SCIM/GitHub-SCIM-Provisioning-Overview.png)
- [Repository team permissions](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)

## Automation Files

The `Automation/` folder contains **two PowerShell scripts, two synthetic HR CSV inputs, and six sample reports**.

| File | Purpose |
| --- | --- |
| `Remove-CHSDeveloper.ps1` | Validates the simulated request, checks target-role membership, and requires operator acknowledgment before removing obsolete Developer access. Published version defaults to dry run. |
| `CHS-TestMoverFinalState.ps1` | Checks four expected Entra group memberships, performs two simulated negative tests, and exports CSV validation results. |
| `Sample-Inputs/` | Fictional HR transfer and manager approval records. |
| `Sample-Reports/` | Historical access baseline, dry-run plan, execution, removal, final-state, and exception-test results. |

### Automation Scope

The scripts use Microsoft Graph PowerShell to query and modify Microsoft Entra security-group membership.

Published sample inputs use the placeholder `jordan.lee@chs.example`, not a live account.

The current scripts do not independently authenticate manager approval, automate the initial Project Lead grant, or query GitHub to verify downstream entitlements.

The publication-ready scripts were cleaned and improved but have not yet been retested against Entra.

## Security Findings and Limitations

| Finding | Status |
| --- | --- |
| CA-001 baseline MFA applies only to the pilot group | Broader CA-006 policy evaluated with What If; remains Report-only |
| Original administrator retains standing Global Administrator access | Identified; not remediated |
| GitHub SCIM credential requires expiration and rotation controls | Provisioning verified; rotation untested |
| SAML replacement certificate staged, but rollover failed | Original SSO operational; replacement unverified |
| Risk-based Conditional Access (CA-004/005) | Report-only; no live risk-event validation |
| Automated cross-system access drift detection | Not implemented; manual verification performed |

This is a simulated laboratory environment, not a production deployment or a formal HIPAA or ISO certification assessment.

HR approval records are synthetic, and no real patient data is used.

Duo External MFA and a patient-facing CIAM portal were evaluated as architecture exercises rather than live integrations.

Expanded Joiner/Leaver automation and additional user access review work are planned enhancements, not completed results.

## Repository Structure

```text
Cedarbridge-Enterprise-IAM/
├── README.md
├── Architecture/
│   └── CHS-Identity-Architecture.png
├── Automation/
│   ├── Scripts/
│   ├── Sample-Inputs/
│   └── Sample-Reports/
├── Documentation/
└── Evidence/
    ├── 01-Conditional-Access/
    ├── 02-Privileged-Access/
    ├── 03-OIDC-SCIM/
    ├── 04-Entitlement-Management/
    ├── 05-Access-Reviews/
    ├── 06-JML-Automation/
    ├── 07-SAML-Federation/
    └── 08-Security-Assessment/
```

## Documentation

Supporting documentation includes:

- [IAM Security Standard](Documentation/CHS-IAM-Security-Standard.md)
- [Identity Lifecycle SOP](Documentation/CHS-Identity-Lifecycle-SOP.md)
- [IAM Operations Runbook](Documentation/CHS-IAM-Operations-Runbook.md)
- [IAM Control Assessment](Documentation/CHS-IAM-Control-Assessment.md)
- [CIAM Architecture Proposal](Documentation/CHS-CIAM-Architecture-Proposal.md)

## Technologies

**Identity & Authentication:** Microsoft Entra ID P2, Conditional Access, MFA, PIM

**Federation:** OIDC, OAuth 2.0, SAML 2.0

**Provisioning & Governance:** SCIM, Entitlement Management, Access Reviews, RBAC

**Automation:** PowerShell 7, Microsoft Graph PowerShell SDK, CSV validation and reporting

**Application:** GitHub Enterprise Cloud (Enterprise Managed Users)

**Security Frameworks:** NIST SP 800-53, ISO/IEC 27001, CIS Controls

---

*All organizational identities and scenarios are fictional. Public screenshots and sample files are sanitized for demonstration purposes.*
