# Enterprise Identity Security & Governance | Microsoft Entra ID

**GitHub Enterprise Managed Users · OIDC · SCIM · Conditional Access · PIM · Identity Governance · Zammad SAML SSO**

## Problem Statement

Cedarbridge Health System (CHS) is a **fictional healthcare organization** integrating three newly acquired clinics. Its clinical integration team needs access to GitHub repositories, contractors need temporary access to support projects, and employees need an IT support desk when something goes wrong.

Giving someone an account is straightforward. **Proving that they received the right permissions—and that those permissions were removed when no longer needed—is harder.** CHS needed to address several risks:

- **Inconsistent application access:** Employees could authenticate, but their actual permissions still depended on assignments inside each application.
- **Uncontrolled privileged access:** Administrative roles needed stronger authentication and time-limited activation instead of unnecessary standing access.
- **Weak approval and review evidence:** Temporary access needed a documented business justification, a manager's decision, and a way to verify the outcome of an access review.
- **Different permissions for different users:** Employees submitting support requests should not receive the same Zammad permissions as the agents resolving them.

**My objective:** Build a centralized identity security environment in Microsoft Entra ID, integrate the applications, and test the controls from initial access approval through recertification and application-level authorization.

## Solution Overview

I built an enterprise IAM lab using **Microsoft Entra ID as the workforce identity provider**, with GitHub Enterprise Cloud and Zammad as connected applications. Rather than only configuring the tools, I tested what happened when users requested access, when that access was reviewed, and when two employees needed different permissions in the same application.

- Integrated **GitHub Enterprise Managed Users** with Entra through **OIDC single sign-on** and **SCIM user/group provisioning**; assigned repository access through role-based GitHub teams.
- Configured **Conditional Access**, **PIM/JIT administrative access**, and emergency account protections to reduce authentication and privilege risk.
- Used **Entitlement Management and Access Reviews** to document a contractor's access request, manager approval, recertification decision, and separate remediation verification.
- Connected **Zammad to Entra using SAML 2.0** and tested the difference between a Customer who submits tickets and an Agent who manages them.

[View the identity architecture](Architecture/CHS-Identity-Architecture.md) · [Browse supporting evidence](Evidence/)

---

## Implementation & Testing

### 1. Securing access to GitHub Enterprise

CHS's clinical integration team needed GitHub access without making every employee an organization-wide contributor. I started by establishing the authentication, provisioning, and authorization controls.

**What I configured:**

- **OIDC SSO:** Connected GitHub Enterprise Cloud (Enterprise Managed Users) to Entra ID so workforce authentication runs through the organization's identity provider.
- **SCIM provisioning:** Configured assigned-user and group synchronization from Entra to GitHub, then checked provisioning activity and downstream memberships.
- **Repository RBAC:** Mapped Developer and Project Lead groups to GitHub teams with **Write** and **Maintain** permissions, respectively. Set default repository access to **None**.
- **Conditional Access:** Tested enabled MFA and privileged-account policies, along with legacy-authentication restrictions. Broader MFA and risk-based policies remained **Report-only** rather than fully enforced.
- **PIM:** Tested time-limited activation of an eligible **Cloud Application Administrator** role and verified two emergency administrator sign-ins.

**Why the distinction matters:** OIDC handles *authentication*. SCIM handles *provisioning*. GitHub team and repository settings determine *authorization*. Successful sign-in by itself does not prove the user has the right repository access. SCIM synchronization is also asynchronous, so I checked the downstream state rather than assuming every directory change was immediately reflected in GitHub.

**Evidence:** [Conditional Access policies](Evidence/01-Conditional-Access/CA-Policies-Overview.png) · [PIM activation](Evidence/02-Privileged-Access/PIM-CloudAppAdmin-Successful-Activation.png) · [SCIM provisioning](Evidence/03-OIDC-SCIM/GitHub-SCIM-Provisioning-Overview.png) · [GitHub team permissions](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)

### 2. Approving access—and checking whether it was actually removed

**The request:** Taylor Morgan, a temporary contractor, needed Developer access for clinical integration work. Instead of manually adding access without an approval trail, I created the **`CHS-Integration-Developer-Access`** access package in Entra Entitlement Management, added the appropriate group resource, and configured manager approval. Taylor submitted a request, and **Daniel Kim approved it**.

**The review:** Later, Taylor's assignment ended. In an access review of **`SG-CHS-GH-Developers`**, **Marcus Reid denied Taylor's continued access** and approved Jordan Lee's access based on Jordan's business need **at the time of the review**.

I downloaded a **sanitized CSV of the review decisions** and compared it with the actual access state. This exposed an important difference:

| Review evidence | Observed result |
| --- | --- |
| Taylor's decision | **Deny** — contractor assignment ended |
| Jordan's decision | **Approve** — Developer access justified at review time |
| Exported apply status | **Not applied** for both decisions |
| Separate remediation | Taylor's access-package assignment was revoked outside the review's automatic enforcement |
| Final-state checks | The Entra Developer group and linked GitHub Developer team both showed **0 members** |

**Important qualification:** The review was still active. Its exported decisions had **not** been applied by the review engine. Jordan's Developer membership was also removed later during a separate exercise, which explains why the final group was empty despite his earlier approval. The group/team screenshots confirm the access state **when checked**, not the exact removal event or its cause.

**What this demonstrated:** A completed reviewer decision is not proof of completed remediation. An IAM analyst needs to reconcile **approval or denial → action taken → downstream verification**, preserving the evidence for each step.

**Evidence:** [Access-package approval](Evidence/04-Entitlement-Management/Access-Package-Approval-Success.png) · [Review results](Evidence/05-Access-Reviews/Access-Review-Individual-Results.png) · [Sanitized CSV reconciliation](Evidence/05-Access-Reviews/CHS-UAR-Decision-Reconciliation.csv) · [Entra final group state](Evidence/05-Access-Reviews/UAR-Entra-Developer-Group-All-Members.png) · [GitHub final team state](Evidence/05-Access-Reviews/UAR-GitHub-Developer-Team-Final-State.png)

[Read the UAR audit reconciliation](Documentation/CHS-UAR-Audit-Reconciliation.md)

### 3. Extending SSO and least privilege to the IT support desk

CHS also needed a way for employees to request help without giving them the same permissions as support staff. I integrated **Zammad** as the **CHS - Clinic Integration Support Desk** application in Entra ID.

**What I configured and tested:**

- **SAML SSO:** Configured the application's Entity ID and Assertion Consumer Service (ACS) URL, and supplied Entra's identity-provider login information and public signing certificate to Zammad.
- **Entra assignment and sign-in validation:** Assigned test users, signed in through **CHS Employee SSO**, and located the successful Zammad application sign-in in Entra's logs. Reviewed Conditional Access separately rather than treating a successful SAML response as proof of fresh MFA.
- **Customer permissions:** Jordan submitted a fictional **EHR Integration Portal – Access Issue** ticket, could view his own tickets, and could not access agent ticket-management functions.
- **Agent permissions:** Marcus received the Zammad **Agent** role and **Full** access to the `Users` ticket group. He took ownership of Jordan's ticket and sent a public response.
- **Administrative recovery:** Kept the original local administrator login available while testing the federation setup.

**The result:** Entra determines whether Jordan and Marcus can authenticate to Zammad; **Zammad's own roles determine what they can do after signing in**. This is why an Entra application-access review alone would not fully recertify Zammad's local Agent and Admin assignments.

The support ticket was fictional and did **not** change real EHR permissions or involve patient data.

**Evidence:** [CHS SSO login](Evidence/06-Zammad-SAML-RBAC/Zammad-CHS-Employee-SSO-Login.png) · [Jordan's Customer view](Evidence/06-Zammad-SAML-RBAC/Zammad-Jordan-Customer-Initial-Dashboard.png) · [Marcus's Agent permissions](Evidence/06-Zammad-SAML-RBAC/Zammad-Marcus-Agent-Group-Permissions.png)

[Read the Zammad SSO and RBAC test](Documentation/CHS-Zammad-SSO-RBAC-Test.md)

---

## Findings & Limitations

- **Access-review enforcement:** The decisions were recorded, but the export showed **Not applied**. Separate removals and final-state checks must not be described as automated review enforcement.
- **Conditional Access coverage:** Selected policies were active; broader MFA and risk-based policies remained **Report-only**.
- **Privilege management:** PIM activation was tested, but an original standing Global Administrator assignment remained an identified risk.
- **Provisioning and recertification:** GitHub SCIM was tested; automated cross-application drift detection, SCIM credential rotation, scheduled UAR CSV exports, and automated reviews of Zammad's local roles were **not implemented**.

## Repository Contents

| Location | Contents |
| --- | --- |
| [`Architecture/`](Architecture/CHS-Identity-Architecture.md) | Entra, GitHub, governance, and Zammad architecture diagram |
| [`Evidence/`](Evidence/README.md) | Screenshots and sanitized CSV evidence organized by control |
| [`Documentation/CHS-UAR-Audit-Reconciliation.md`](Documentation/CHS-UAR-Audit-Reconciliation.md) | Reviewer decisions, remediation findings, and verification limits |
| [`Documentation/CHS-Zammad-SSO-RBAC-Test.md`](Documentation/CHS-Zammad-SSO-RBAC-Test.md) | SAML configuration, authentication validation, and application RBAC test |

*CHS, its employees, and its business scenarios are fictional. This is a controlled technical lab—not a production implementation or HIPAA compliance certification. No patient data was used.*
