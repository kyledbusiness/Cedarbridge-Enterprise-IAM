# Enterprise Identity Security & Governance
### Cedarbridge Health System | Microsoft Entra ID • GitHub Enterprise • PowerShell

## The Problem

**Removing a user from a security group doesn't always mean their application access is gone.**

I saw this firsthand while testing an employee role change. Microsoft Entra ID showed that the previous group membership had been removed, but GitHub Enterprise continued displaying the old entitlement until SCIM synchronization caught up.

That gap raised a bigger question:

**How can an IAM team prove that access was approved, provisioned correctly, reviewed regularly, and actually removed when it is no longer needed?**

This project explores that question through a simulated healthcare organization.

### Business Scenario

Cedarbridge Health System (CHS) recently acquired three clinics and is consolidating its identity infrastructure.

The organization needs to support a clinical software integration initiative involving employees, privileged administrators, and temporary engineering access.

However, several identity security risks need to be addressed:

- Inconsistent access assignments across departments and applications.
- Excessive privileges and standing administrative access.
- Manual or incomplete approval evidence.
- Delayed application deprovisioning.
- Limited visibility into whether directory changes reached downstream applications.
- Incomplete authentication coverage and credential lifecycle processes.

**My objective:** Design, implement, test, and assess an enterprise identity security architecture that addresses these risks.

---

## Solution Overview

I built a simulated IAM environment using Microsoft Entra ID P2 as the central workforce identity provider and GitHub Enterprise Cloud as a connected enterprise application.

The environment combines authentication, authorization, provisioning, privileged access, identity governance, and lifecycle automation.

| Capability | Implementation |
|---|---|
| Workforce identity | Microsoft Entra ID |
| Authentication policies | Conditional Access and MFA |
| Privileged administration | Entra Privileged Identity Management (PIM) |
| Enterprise SSO | OIDC and SAML 2.0 |
| Automated provisioning | SCIM |
| Application authorization | Security groups, GitHub teams, and repository permissions |
| Access requests | Entra Entitlement Management |
| Access recertification | Entra Access Reviews |
| Employee role changes | Microsoft Graph PowerShell |
| Monitoring and investigation | Entra audit/provisioning logs and GitHub audit logs |
| Governance assessment | NIST SP 800-53, ISO 27001, and CIS Controls |

**Environment:** Isolated laboratory with fictional users and synthetic organizational records.

---

## Architecture

The implementation uses Entra ID as the authoritative source for workforce application access.

### Workforce authentication

- Users authenticate through Entra ID.
- Conditional Access evaluates applicable authentication requirements.
- GitHub Enterprise Managed Users uses OIDC for SSO.
- A simulated Employee Operations Portal uses SAML 2.0.

### GitHub access provisioning

1. Approved access is represented by Entra security-group membership.
2. Entra's provisioning service synchronizes identities and groups through SCIM.
3. GitHub maps the external groups to organization teams.
4. Team permissions determine the user's repository access.

### Identity governance

- Entitlement Management handles eligible access requests and manager approvals.
- Access Reviews provide recurring recertification decisions.
- PIM provides time-limited activation of eligible administrative roles.
- PowerShell supports validated identity lifecycle changes.

The complete architecture diagram will be added to the `Architecture/` folder.

---

## Implementation & Testing

### 1. Conditional Access and Authentication Security

Configured policies for baseline MFA, phishing-resistant administrator authentication, legacy authentication blocking, and risk-based access controls.

The laboratory also includes two emergency administrator accounts with tested FIDO2 authentication.

**Assessment finding:** The original baseline MFA policy targets only five of eleven identities. Excluding the two emergency accounts, four non-emergency accounts remain outside that policy's scope.

I created a broader Report-only policy and validated its targeting using Conditional Access What If.

**Limitation:** Tenant-wide enforcement has not been completed.

### 2. Privileged Identity Management

Configured eligible Cloud Application Administrator access for Sophia Patel's administrative account.

Tested time-limited role activation and verified the active assignment.

**Governance finding:** The original lab administrator retains standing Global Administrator privileges. This remains an identified risk rather than a completed remediation.

### 3. GitHub Enterprise Integration — OIDC and SCIM

Integrated GitHub Enterprise Cloud using Enterprise Managed Users.

Configured:

- OIDC single sign-on through Microsoft Entra ID.
- SCIM user and group provisioning.
- Assigned-user-and-group provisioning scope.
- IdP-connected GitHub organization teams.
- Role-based repository permissions.

The Developer team receives **Write** permission, while the Project Lead team receives **Maintain** permission.

GitHub's default repository permission was set to **None** to avoid automatically granting repository access through organization membership.

### 4. Entitlement Management and Access Reviews

Created an access package for temporary GitHub developer access with manager approval.

Tested access request submission, approval, group assignment, and downstream provisioning.

Also configured and completed a GitHub developer access review involving two identities.

| Review outcome | Result |
|---|---|
| Jordan Lee | Access approved |
| Taylor Morgan | Access denied |

After Taylor's denial, I separately revoked the access-package assignment and verified downstream SCIM deprovisioning.

**Important distinction:** The review decision and access-package removal were separate actions. I did not treat the review result alone as proof that access had been removed.

### 5. PowerShell Identity Lifecycle Automation

Simulated an employee promotion from Developer to Project Lead.

**Change request:** `CHS-MOV-001`  
**Employee:** Jordan Lee  
**Manager:** Daniel Kim

The workflow used Microsoft Graph PowerShell, simulated HR transfer data, and simulated approval records.

The process:

1. Validated the transfer and authorization data.
2. Captured the existing access baseline.
3. Generated a dry-run report.
4. Added the required Project Lead membership.
5. Verified downstream Project Lead access in GitHub.
6. Removed the obsolete Developer membership.
7. Investigated the delay before GitHub reflected the removal.
8. Validated the final Entra membership state.

**Final-state results**

| Entitlement | Expected | Observed |
|---|---|---|
| GitHub Developers | Removed | Removed |
| GitHub Project Leads | Present | Present |
| Conditional Access pilot | Retained | Retained |
| Employee Portal | Retained | Retained |

All four checked Entra group memberships matched the expected state.

The workflow also rejected test requests with invalid approval or unsupported target-role conditions.

**Limitation:** The input files simulate HR and manager authorization. They do not replace a trusted HRIS or production approval platform.

### 6. SAML Federation and Troubleshooting

Configured the Microsoft Entra SAML Toolkit as a simulated Employee Operations Portal.

Tested:

- Successful SP-initiated authentication.
- Group-based application assignment.
- Denial of an unassigned user (`AADSTS50105`).
- Deliberate ACS mismatch (`AADSTS50011`).
- Restoration of the working SAML configuration.

Also staged a replacement signing certificate.

**Outstanding finding:** Certificate rollover could not be completed because the service-provider toolkit returned an error while saving the replacement. The original federation remained functional.

### 7. Identity Monitoring and Security Assessment

Investigated identity events across Microsoft Entra and GitHub Enterprise.

For the mover workflow, correlated:

- PowerShell execution results.
- Entra group membership audit events.
- SCIM provisioning activity.
- GitHub external-group membership events.
- GitHub team removal events.

The investigation confirmed that the original Developer entitlement was eventually removed from GitHub following scheduled synchronization.

Additional security assessment work covered MFA policy scope, standing privileges, SCIM credential lifecycle, certificate rollover, and risk-based access monitoring.

---

## Key Security Findings

| Finding | Assessment status |
|---|---|
| Incomplete baseline MFA scope | Broader Report-only policy evaluated |
| Standing Global Administrator access | Remediation proposed |
| SCIM credential lifecycle | Rotation controls recommended |
| SAML certificate rollover | Incomplete; recovery procedure documented |
| Risk-based Conditional Access | Report-only; live enforcement unverified |
| SCIM synchronization delay | Observed discrepancy resolved; continuous drift monitoring recommended |

These are preliminary laboratory findings, not the outcome of a formal compliance audit.

---

## Documentation & Evidence

The repository includes supporting operational documentation:

- **IAM Security Standard:** Authentication, federation, privileged access, provisioning, and security baseline.
- **Identity Lifecycle SOP:** Joiner, Mover, and Leaver procedures.
- **IAM Operations Runbook:** Troubleshooting, incident investigation, recovery, and escalation.
- **Control Assessment Register:** Risks, framework mappings, evidence, and remediation plans.
- **CIAM Architecture Proposal:** A patient-facing External ID design, not a deployed integration.

Screenshots and execution reports will be organized by control area in the `Evidence/` folder.

Sensitive credentials, recovery codes, tokens, and unnecessary identifying details are excluded from public materials.

---

## Lessons Learned

### A successful API response isn't the end of an access change.

Microsoft Entra accepted Jordan's group removal before GitHub reflected it.

The actual security outcome required checking both systems and correlating the provisioning and application audit evidence.

### Approval, provisioning, and verification are different controls.

A manager approving access doesn't prove that the correct permission was assigned.

Likewise, an access review denial doesn't automatically prove revocation.

Each stage requires its own evidence.

### Identity governance must include operational failure scenarios.

During testing, I encountered SAML configuration failures, certificate rollover limitations, provisioning delays, and incomplete security-policy coverage.

These findings were documented rather than presented as successful implementations.

### IAM engineering and GRC reinforce each other.

The technical work establishes how identity controls operate. The governance assessment establishes whether those controls are appropriately scoped, documented, monitored, and effective.

---

## Scope & Limitations

This is a simulated healthcare identity environment.

The project does not use real patient records or production employee identities.

Duo External MFA was evaluated as an architecture exercise only. Microsoft Entra External ID patient registration was also designed but not implemented because the available tenant-creation process required an Azure subscription.

Risk-based Conditional Access remains in Report-only mode, and automated cross-system drift detection is a future improvement.

The project demonstrates implemented IAM controls, controlled laboratory testing, and documented risk assessment—not a certified or production-ready healthcare deployment.

---

## Technologies

**Identity & Security:** Microsoft Entra ID, Conditional Access, PIM, Entitlement Management, Access Reviews, Microsoft Graph, GitHub Enterprise Managed Users

**Protocols:** OIDC, OAuth 2.0, SAML 2.0, SCIM

**Automation:** PowerShell 7, Microsoft Graph PowerShell SDK, CSV-based validation and reporting

**Governance:** RBAC, least privilege, JML, access recertification, audit evidence, NIST SP 800-53, ISO/IEC 27001, CIS Controls

---

*Project developed as an independent identity security and governance laboratory using fictional Cedarbridge Health System scenarios.*
