# Cedarbridge Health System — Enterprise Identity Security & Governance

**Microsoft Entra ID | GitHub Enterprise | OIDC | SCIM | Conditional Access | PIM | Identity Governance**

## The Problem: Who Still Has Access?

Cedarbridge Health System (CHS) is a fictional healthcare organization integrating three newly acquired clinics.

As part of the acquisition, internal engineers and temporary contractors needed to collaborate on a clinical systems integration project using GitHub Enterprise.

But giving everyone access was only half the problem.

The CISO needed answers to three questions:

- **Who approved access?** Engineers and contractors needed different permissions, with a clear business justification.
- **Who still needed access?** Promotions, transfers, and contract expirations could leave employees holding permissions they no longer required.
- **How could IT prove access was revoked?** Removing someone from an identity-provider group didn't necessarily mean the downstream application had updated.

The organization needed a way to provision access efficiently while maintaining least privilege, accountability, and audit evidence.

**My objective:** Build an identity security solution that centralized authentication, governed access requests, managed privileged access, and verified that permissions were removed when no longer justified.

## The Solution

I designed and implemented a simulated enterprise IAM environment using **Microsoft Entra ID P2** as the workforce identity provider and **GitHub Enterprise Cloud** as the connected application.

| Business requirement | My implementation |
|---|---|
| Centralize authentication | Integrated GitHub Enterprise Managed Users with Entra ID using OIDC SSO |
| Automate application provisioning | Configured SCIM user and group provisioning |
| Enforce least privilege | Mapped Entra groups to GitHub teams with Write and Maintain repository permissions |
| Secure administrative access | Configured Conditional Access and PIM for time-limited privileged role activation |
| Require business approval | Created an Entitlement Management access package with manager approval |
| Review existing access | Conducted an Entra access review with documented approval and denial decisions |
| Manage employee transfers | Used Microsoft Graph PowerShell to validate and execute a controlled role change |
| Prove access removal | Correlated Entra audit records, provisioning activity, and GitHub audit logs |

## How I Tested It

### Scenario 1 — A Contractor No Longer Needs Access

**Employee:** Taylor Morgan, temporary integration contractor

Taylor requested access to the GitHub Developer group through `CHS-Integration-Developer-Access`.

I configured a manager-approval workflow where Daniel Kim reviewed the request and approved access for the integration project.

Later, during an access review, Marcus Reid determined Taylor no longer had a valid business need.

**Actions and results:**

1. Taylor submitted an access-package request.
2. Daniel approved the request.
3. Entra assigned the approved entitlement.
4. Marcus subsequently denied Taylor's access during recertification.
5. Taylor's access-package assignment was separately revoked.
6. Downstream SCIM deprovisioning was verified.

**Outcome:** The workflow demonstrated business approval, periodic review, and verified revocation—not just a recorded access-review decision.

[Manager approval evidence](Evidence/04-Entitlement-Management/Access-Package-Approval-Success.png)

[Access review results](Evidence/05-Access-Reviews/Access-Review-Individual-Results.png)

### Scenario 2 — A Promotion Creates an Access Risk

**Employee:** Jordan Lee  
**Change request:** `CHS-MOV-001`  
**Transition:** Developer → Project Lead

Jordan was promoted to Project Lead and required Maintain access to the integration repository.

The challenge was granting his new permissions while removing his old Developer entitlement without disrupting unrelated access.

I used Microsoft Graph PowerShell, simulated HR and approval records, and a controlled add–verify–remove process.

| Security group | Before | After |
|---|---|---|
| GitHub Developers | Member | Removed |
| GitHub Project Leads | Not a member | Member |
| Conditional Access Pilot | Member | Preserved |
| Employee Portal | Member | Preserved |

**The unexpected finding**

After removing Jordan from the Developer group in Entra ID, GitHub still displayed his previous membership.

I investigated the provisioning process and correlated the directory changes with GitHub enterprise audit events.

The subsequent SCIM synchronization removed Jordan from the GitHub Developer external group and organization team.

**Outcome:** All four Entra membership checks matched the expected final state, and GitHub audit logs separately confirmed removal of the obsolete entitlement.

**Lesson learned:** A successful directory operation does not prove downstream access has been revoked. The IAM team must verify the actual application state.

[PowerShell removal execution](Evidence/06-JML-Automation/JML-Developer-Removal-Execution.png)

[Final Entra access validation](Evidence/06-JML-Automation/JML-Mover-Final-State-Validation.png)

[GitHub SCIM removal audit](Evidence/06-JML-Automation/Jordan-GitHub-SCIM-Member-Removal.png)

## Supporting Security Controls

### Conditional Access

Configured policies for baseline MFA, phishing-resistant authentication for privileged identities, and legacy authentication blocking.

Additional risk-based policies and a broader MFA rollout policy were configured in Report-only mode.

[Conditional Access policy overview](Evidence/01-Conditional-Access/CA-Policies-Overview.png)

### Privileged Identity Management

Configured an eligible Cloud Application Administrator role and validated time-limited PIM activation.

Two emergency administrator accounts were also tested for successful FIDO2 sign-in.

[PIM activation evidence](Evidence/02-Privileged-Access/PIM-CloudAppAdmin-Successful-Activation.png)

### Application RBAC

Configured GitHub Developer and Project Lead teams with Write and Maintain permissions. Default repository permission was set to None.

[GitHub repository permissions](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)

### SAML Federation

Integrated a simulated Employee Operations Portal using SAML 2.0.

Tested successful sign-in, application assignment enforcement, and an intentional ACS URL misconfiguration that produced `AADSTS50011`. Restored the configuration and verified authentication.

[SAML authentication failure](Evidence/07-SAML-Federation/SAML-ACS-Mismatch-AADSTS50011.png)

[SAML successful sign-in](Evidence/07-SAML-Federation/SAML-Authorized-SignIn.png)

## Automation

The `Automation/` folder contains two PowerShell scripts, simulated HR request and approval records, and six execution/validation reports.

- **Remove-CHSDeveloper.ps1:** Validates the simulated role change, requires operator confirmation, and supports removal of obsolete Developer group access.
- **CHS-TestMoverFinalState.ps1:** Verifies the expected Entra group memberships and exercises simulated invalid-request checks.
- **Sample-Inputs:** Fictional HR transfer and approval CSVs.
- **Sample-Reports:** Baseline, dry-run, execution, removal, exception-testing, and final-state evidence.

The original Mover exercise included manual GitHub verification. The published scripts do not independently verify downstream GitHub entitlements, and their sanitized versions have not been retested against the tenant.

## Security Assessment

During testing, I also identified control gaps requiring further evaluation:

| Finding | Status |
|---|---|
| Limited baseline MFA scope | Broader Report-only policy evaluated |
| Original administrator retained standing Global Administrator access | Remediation recommended |
| SCIM credential expiration and rotation | Operational dependency documented |
| SAML signing certificate rollover | Replacement staged; rollover incomplete |
| Delayed downstream access changes | Observed discrepancy resolved; automated drift monitoring recommended |

Rather than presenting every configuration as production-ready, I documented the outstanding risks and proposed remediation.

## Key Takeaways

**Identity governance requires more than assigning access.**

This project demonstrated how business approvals, application provisioning, privileged access controls, periodic reviews, and audit evidence fit together.

The biggest lesson came from investigating the gap between Entra ID and GitHub. The directory showed the requested change, but verifying the actual security outcome required following it all the way to the application.

## Technology Stack

- **Identity:** Microsoft Entra ID P2, Active Directory concepts, Microsoft Graph
- **Authentication:** OIDC, SAML 2.0, MFA, Conditional Access, FIDO2
- **Governance:** PIM, Entitlement Management, Access Reviews, RBAC
- **Provisioning:** SCIM, GitHub Enterprise Managed Users
- **Automation:** PowerShell 7, Microsoft Graph PowerShell SDK
- **Frameworks:** NIST SP 800-53, ISO 27001, CIS Controls

*This project uses a fictional healthcare environment and simulated employee records. It is not a production deployment or formal compliance certification.*
