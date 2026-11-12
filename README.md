# Cedarbridge Health System | Enterprise Identity Security & Governance

**Microsoft Entra ID · GitHub Enterprise Managed Users · OIDC · SCIM · Conditional Access · PIM · Entitlement Management · Access Reviews · Zammad SAML SSO**

> **Getting someone into an application is the easy part. Can you explain who approved that access, what they can do once inside, and whether they still have it when the business need disappears?**

That question drove this lab. I built the identity environment for **Cedarbridge Health System (CHS)**, a fictional healthcare organization integrating three newly acquired clinics. Its clinical integration team needed controlled GitHub access, temporary contractors needed an accountable approval process, and employees needed an internal support desk. A successful sign-in alone would not satisfy those requirements.

I followed one access story from the initial security controls to an access request, a later recertification, and a second application's authorization test. Along the way, I learned that **review decisions, directory memberships, and downstream application access are three different types of evidence**.

**Start here:** [Identity architecture](Architecture/CHS-Identity-Architecture.md) · [Evidence index](Evidence/README.md)

## The foundation — secure the doors before opening them

CHS needed a central identity provider, predictable application permissions, and a way to manage administrators without giving everyone standing privileged access.

| Control | Implementation | Security purpose |
| --- | --- | --- |
| **GitHub OIDC SSO** | Integrated Microsoft Entra ID with **GitHub Enterprise Cloud (Enterprise Managed Users)**. | Workforce users authenticate through the organization's identity provider. |
| **SCIM provisioning** | Configured user and group provisioning from Entra to GitHub, with provisioning and membership checks. | An identity can be authenticated without automatically having the correct application entitlements; provisioning must be verified separately. |
| **GitHub RBAC** | Mapped Developer and Project Lead groups to GitHub teams with **Write** and **Maintain** permissions; set the default repository permission to **None**. | Access is assigned according to role, not simply because a person has an account. |
| **Conditional Access** | Tested enabled MFA/privileged-account controls and legacy-authentication restrictions; kept broader MFA and risk policies in **Report-only**. | Reduce authentication risk while clearly distinguishing enforced controls from simulated policy evaluations. |
| **PIM / JIT** | Validated time-limited activation of an eligible **Cloud Application Administrator** role and tested two emergency administrator sign-ins. | Separate normal access from privileged administrative activity. |

**What I checked:** [Conditional Access policy overview](Evidence/01-Conditional-Access/CA-Policies-Overview.png) · [PIM activation](Evidence/02-Privileged-Access/PIM-CloudAppAdmin-Successful-Activation.png) · [SCIM provisioning](Evidence/03-OIDC-SCIM/GitHub-SCIM-Provisioning-Overview.png) · [GitHub team permissions](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)

With that foundation established, CHS could grant access through a documented business decision instead of an ad hoc group change.

## The access story — approve, review, and verify

### Chapter 1 — Taylor needs access, but not forever

**The request.** Taylor Morgan, a temporary contractor, needed Developer access to the clinical integration team's GitHub repositories. The business needed to know *who approved it*, *what entitlement was granted*, and *why that access existed*.

I configured the Entra Entitlement Management access package **`CHS-Integration-Developer-Access`** with a security-group resource and manager approval. Taylor submitted a request, and **Daniel Kim approved** it. GitHub's group-based provisioning and team permissions provided the downstream authorization design, rather than assigning Taylor broad organization-level privilege.

**Evidence:** [Access package approval](Evidence/04-Entitlement-Management/Access-Package-Approval-Success.png) · [Provisioning state](Evidence/03-OIDC-SCIM/GitHub-SCIM-Provisioning-Overview.png) · [Team-level RBAC](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)

**The next question:** The approval made sense when Taylor joined the project. Would it still make sense after the contract ended?

### Chapter 2 — An access review isn't the same as revocation

**The review.** Marcus Reid reviewed membership in **`SG-CHS-GH-Developers`**. He **denied Taylor's continued Developer access** because the contractor assignment ended, while **approving Jordan Lee's** Developer access based on its business need *at the time of review*.

I exported the access-review decisions as a sanitized CSV and reconciled them with separate actions and snapshots from Entra and GitHub:

| What the reviewer decided | What the export showed | What I verified separately |
| --- | --- | --- |
| **Taylor — Deny** | `Apply Result: Not applied` | His access-package assignment was separately revoked; the Entra Developer group and linked GitHub Developer team later both showed **0 members**. |
| **Jordan — Approve** | `Apply Result: Not applied` | His Developer membership was changed after the review during a separate exercise outside this repository's scope. The final group/team snapshots therefore also show no Jordan membership. |

**The finding:** The review was still **Active** when inspected. The recorded decisions did **not** show automatic application by the review engine. Likewise, a screenshot of an empty group proves the **state at the time of capture**, not who removed a specific user or precisely when that happened.

That distinction is the heart of the governance work: **decision → action → verified current state**. For a formal audit, I'd also retain the corresponding removal events and timestamps to establish causality, not only the final snapshots.

**Evidence:** [Review decisions](Evidence/05-Access-Reviews/Access-Review-Individual-Results.png) · [Sanitized reconciliation CSV](Evidence/05-Access-Reviews/CHS-UAR-Decision-Reconciliation.csv) · [Entra final membership](Evidence/05-Access-Reviews/UAR-Entra-Developer-Group-All-Members.png) · [GitHub final membership](Evidence/05-Access-Reviews/UAR-GitHub-Developer-Team-Final-State.png) · [Audit interpretation](Documentation/CHS-UAR-Audit-Reconciliation.md)

**The next question:** CHS can manage *who is assigned* to GitHub. But can a second application distinguish a user who needs help from the support agent who handles that request?

### Chapter 3 — A successful login shouldn't make someone an administrator

**The support scenario.** CHS introduced an internal help desk using **Zammad**. Jordan submitted a simulated **EHR Integration Portal access issue**; Marcus handled the request. The ticket did not change any real EHR permissions or patient records.

I connected Zammad to Entra using **SAML 2.0**. The enterprise application supplied the Entity ID and ACS endpoint; Zammad trusted Entra's IdP login information and public signing certificate. I assigned test users and verified Jordan's successful Zammad application sign-in in Entra's logs, then reviewed the applicable Conditional Access results. A successful SAML login alone was **not** treated as proof that fresh MFA occurred.

The more revealing test came *after* authentication:

| Identity | Zammad authorization | Observed behavior |
| --- | --- | --- |
| **Jordan — Customer** | End-user ticket access | Submitted a support request, viewed his own tickets, and could not access agent ticket-management functions. |
| **Marcus — Agent** | `Users` ticket group with Full permission | Took ownership of Jordan's ticket and sent a public response. |
| **Initial administrator — Admin** | Local administrative recovery | Kept existing administrative access available while SAML was tested; this was not an Entra-managed privileged-role mapping. |

**The result:** Entra authenticated the users; **Zammad's local roles decided what they could do**. A review of Entra application assignments would not, by itself, recertify Zammad's Agent or Admin roles.

**Evidence:** [CHS SSO option](Evidence/06-Zammad-SAML-RBAC/Zammad-CHS-Employee-SSO-Login.png) · [Jordan's Customer dashboard](Evidence/06-Zammad-SAML-RBAC/Zammad-Jordan-Customer-Initial-Dashboard.png) · [Marcus's Agent permissions](Evidence/06-Zammad-SAML-RBAC/Zammad-Marcus-Agent-Group-Permissions.png) · [SAML/RBAC test notes](Documentation/CHS-Zammad-SSO-RBAC-Test.md)

*Jordan's submitted-ticket and Marcus's response screenshots were captured during testing. They can be added here once their sanitized copies are placed in the evidence folder.*

## What worked—and what remains open

| Area | Tested outcome or limitation |
| --- | --- |
| **Workforce authentication and provisioning** | GitHub OIDC and SCIM were configured and exercised; provisioning is asynchronous and final application state must be checked. |
| **Administrative controls** | PIM activation was tested; an original standing Global Administrator assignment remained an identified risk. |
| **Conditional Access** | Selected policies were enabled; broader MFA/risk controls remained **Report-only** rather than fully enforced. |
| **Access governance** | Manager approval and reviewer decisions were recorded, but the review export showed **Not applied**. Remediation was verified separately. |
| **UAR reporting** | A sanitized CSV and manual decision-to-remediation reconciliation were produced; **scheduled exports were not implemented**. |
| **Zammad authorization** | Customer/Agent separation was tested; automated provisioning or recertification of Zammad's local roles was **not** implemented. |
| **Operational lifecycle** | SCIM credential rotation and automated cross-application drift monitoring remain future controls, not completed tests. |

## Repository guide

- **[Architecture](Architecture/CHS-Identity-Architecture.md):** one diagram showing the authentication, provisioning, governance, and application-authorization boundaries.
- **[Evidence](Evidence/README.md):** screenshots and a sanitized reconciliation CSV, organized by control area.
- **[UAR reconciliation](Documentation/CHS-UAR-Audit-Reconciliation.md):** what the reviewer decided, what was separately changed, and what the final snapshots establish.
- **[Zammad verification](Documentation/CHS-Zammad-SSO-RBAC-Test.md):** the SAML configuration and observed Customer/Agent behavior.

**Scope:** This is a fictional healthcare IAM lab with simulated users and no patient data. It is not a production deployment, a HIPAA compliance attestation, or a certification assessment. Outcomes are described only to the extent supported by the tests and evidence shown.
