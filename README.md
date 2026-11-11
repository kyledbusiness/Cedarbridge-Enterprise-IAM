# Cedarbridge Health System | Enterprise Identity Security & Governance

**Microsoft Entra ID · GitHub Enterprise Managed Users · Zammad · OIDC / SAML · SCIM · Conditional Access · PIM · Identity Governance · PowerShell**

> **An access request is easy to approve. Proving that access is still appropriate six weeks later—and truly gone when it isn't—is harder.**

That is the problem I set out to investigate in this lab. I built a fictional healthcare identity environment, followed two employees through different access changes, and traced what happened in both Microsoft Entra ID and the applications themselves. The most useful finding was not a successful configuration: it was discovering that Entra could show an entitlement removed while GitHub still showed the old team membership until SCIM synchronization caught up.

## The business problem

Cedarbridge Health System (CHS) is a **fictional healthcare organization** integrating three acquired clinics. Its clinical integration engineers and temporary contractors collaborate in GitHub Enterprise. Its support team also needs an internal desk for access questions. As people join projects, change roles, and finish assignments, the same identity can accumulate permissions across several systems.

The CISO's challenge was to answer three questions with evidence:

1. **Who is allowed in—and who approved it?** Access should depend on organizational policy, role, and business need.
2. **Does access change when the job changes?** Manager decisions, access reviews, and transfers must result in the appropriate entitlements.
3. **How do we know the change reached the application?** Directory success, review decisions, and actual downstream access are not interchangeable.

I implemented the controls, tested them using fictional identities, documented unexpected behavior, and recorded where manual verification was still necessary.

**Explore:** [Architecture](Architecture/CHS-Identity-Architecture.md) · [Evidence guide](Evidence/README.md) · [UAR reconciliation](Documentation/CHS-UAR-Audit-Reconciliation.md) · [Zammad test record](Documentation/CHS-Zammad-SSO-RBAC-Test.md)

## The identity foundation: establish trust before granting access

Before Taylor could request access or Jordan could change roles, I had to establish how CHS users sign in, how accounts reach applications, and who can administer those connections.

| Control | What I configured | Why it mattered |
| --- | --- | --- |
| **OIDC SSO** | Integrated Microsoft Entra ID with **GitHub Enterprise Cloud (Enterprise Managed Users)** for workforce sign-in. | Centralized identity authentication rather than relying on separately managed GitHub credentials. |
| **SCIM provisioning** | Configured Entra-to-GitHub user/group synchronization, tested provisioning, and examined downstream membership changes. | Provisioning is a separate process from signing in; changes are not necessarily instantaneous. |
| **Application RBAC** | Linked Entra Developer and Project Lead groups to GitHub teams with **Write** and **Maintain** permissions; set repository default permission to **None**. | A valid sign-in should not automatically grant broad repository access. |
| **Conditional Access** | Configured enabled pilot/privileged policies and legacy-authentication controls; evaluated broader MFA/risk policies in **Report-only** mode. | Enforces selected authentication requirements while keeping unevaluated rollout changes visible as tests, not deployed controls. |
| **PIM / JIT** | Tested eligible **Cloud Application Administrator** activation and limited-duration privileged access; tested two emergency-account sign-ins. | Administrative privilege should be activated when needed, not treated as ordinary standing access. |

**Evidence:** [Conditional Access policies](Evidence/01-Conditional-Access/CA-Policies-Overview.png) · [PIM activation](Evidence/02-Privileged-Access/PIM-CloudAppAdmin-Successful-Activation.png) · [SCIM provisioning](Evidence/03-OIDC-SCIM/GitHub-SCIM-Provisioning-Overview.png) · [GitHub team permissions](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)

The controls above are the foundation. The following events show how they behaved when real access decisions had to be made.

## The access lifecycle: four connected investigations

### 1. Request and approve — Taylor joins the integration work

**Business need:** Taylor Morgan is a temporary contractor who needs Developer access to contribute to the clinical integration project. Granting access informally would make it difficult to identify who authorized it or when it should expire.

I created the Entra Entitlement Management access package **`CHS-Integration-Developer-Access`** with a manager-approval policy and a security-group resource. Taylor submitted a request; **Daniel Kim approved it**. The approved entitlement made Taylor eligible for the Developer group, which was synchronized to GitHub through the configured provisioning integration.

This tested the handoff between **business approval → group-based authorization → downstream provisioning**. The GitHub team mapped to the Developer role with Write permission; access did not require granting Taylor an administrator role.

**Evidence:** [Manager approval](Evidence/04-Entitlement-Management/Access-Package-Approval-Success.png) · [SCIM provisioning](Evidence/03-OIDC-SCIM/GitHub-SCIM-Provisioning-Overview.png) · [GitHub role mapping](Evidence/03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png)

**Next question:** Approval was justified when Taylor joined. What happens when the contract ends?

### 2. Re-certify and reconcile — Taylor's access is no longer justified

**Business change:** Taylor's contractor assignment ended. Marcus Reid conducted an Entra access review of **`SG-CHS-GH-Developers`**. He **denied Taylor's continued access** and **approved Jordan's**, based on Jordan's then-current Developer responsibilities.

I exported the review decisions to CSV and reconciled the records against separate remediation and final-state evidence:

| Identity | Review decision | Review export: Apply Result | Independently checked outcome |
| --- | --- | --- | --- |
| Jordan | Approve (at the time of review) | `Not applied` | Developer access removed later through a separate mover workflow |
| Taylor | Deny | `Not applied` | Access-package assignment revoked separately; final Entra group and GitHub team both showed zero members |

The review was **active** when inspected. Its decisions were recorded but **not shown as applied by the review system**. The final snapshots prove that the Entra Developer group and linked GitHub Developer team had **zero members at the time of verification**; they do **not** prove that the review automatically enforced removal, nor do they establish Taylor's precise removal event timestamp.

**Evidence:** [Review results](Evidence/05-Access-Reviews/Access-Review-Individual-Results.png) · [Reconciliation CSV](Evidence/05-Access-Reviews/CHS-UAR-Decision-Reconciliation.csv) · [Entra final group state](Evidence/05-Access-Reviews/UAR-Entra-Developer-Group-All-Members.png) · [GitHub final team state](Evidence/05-Access-Reviews/UAR-GitHub-Developer-Team-Final-State.png) · [Audit interpretation](Documentation/CHS-UAR-Audit-Reconciliation.md)

**What I learned:** A reviewer decision, a remediation action, and evidence of the final permissions are three distinct parts of an access review. A CSV export is useful, but reconciling it to the application is what makes it audit-relevant.

**Next question:** Jordan's Developer access was appropriate during the review. What if his responsibilities change the following week?

### 3. Move without permission creep — Jordan becomes Project Lead

**Change request:** `CHS-MOV-001` · **Jordan Lee: Developer → Project Lead**

Jordan needed **Maintain** permissions as Project Lead, but should no longer retain the former **Developer Write** entitlement. I used fictional HR transfer and approval CSVs, Microsoft Graph PowerShell, and a controlled **add → verify → remove** process to validate the change without stripping unrelated access.

| Entra group | Before | Verified final state |
| --- | --- | --- |
| `SG-CHS-GH-Developers` | Member | **Not a member** |
| `SG-CHS-GH-ProjectLeads` | Not a member | **Member** |
| `SG-CHS-CA-Pilot` | Member | **Preserved** |
| `SG-CHS-EmployeePortal-Users` | Member | **Preserved** |

I also exercised simulated invalid-request checks to demonstrate that the workflow should reject a denied approval or unauthorized role rather than silently process it.

**The unexpected result:** Entra showed the Developer group removal, but GitHub still displayed Jordan in the old team. I investigated the delay rather than treating a successful Graph command as proof of access removal. After SCIM synchronization, GitHub audit activity showed the Developer external-group/team membership removed. The final verification combined directory checks with GitHub-side evidence.

**Evidence:** [Removal execution](Evidence/06-JML-Automation/JML-Developer-Removal-Execution.png) · [Final-state validation](Evidence/06-JML-Automation/JML-Mover-Final-State-Validation.png) · [GitHub SCIM removal audit](Evidence/06-JML-Automation/Jordan-GitHub-SCIM-Member-Removal.png)

The `Automation/` folder contains the supporting PowerShell scripts, synthetic request inputs, and sample reports. **Limitations:** the published sanitized scripts have not been retested against the live tenant; the scripts do not independently verify GitHub permissions, and manual downstream validation remained part of the tested procedure.

**Next question:** When Jordan experiences an access issue after the move, can he request help without receiving unnecessary administrative privileges?

### 4. Support the change — Zammad SSO and least-privilege roles

**Support scenario:** Jordan reports an EHR integration portal access problem after his role change. Marcus is the support agent responsible for investigating it. This is a **simulated support ticket**, not a live EHR permission change.

I connected the **CHS Clinic Integration Support Desk (Zammad)** to Entra ID using **SAML 2.0**: configured the enterprise application's Entity ID and ACS URL, provided Zammad with Entra's IdP login information and public signing certificate, assigned test users, and verified a successful Jordan sign-in in Entra's application logs. I inspected applicable Conditional Access evaluations separately rather than assuming that SSO alone proves MFA enforcement.

The crucial test came *after* authentication. Zammad maintains its own application roles:

| Identity | Local Zammad role | Tested behavior |
| --- | --- | --- |
| Jordan | **Customer** | Created a ticket and viewed only his own tickets; no agent management functions |
| Marcus | **Agent** (Users support group) | Took ownership of Jordan's ticket and sent a public reply |
| Original Zammad administrator | **Admin** | Retained local recovery access during SSO configuration |

A first SSO attempt returned a transient HTTP 422 anti-CSRF error. Retrying worked, and subsequent login attempts behaved normally; the underlying cause was **not independently determined**.

**Evidence:** [Zammad SSO login](Evidence/09-Zammad-SAML-RBAC/Zammad-CHS-Employee-SSO-Login.png) · [Jordan Customer view](Evidence/09-Zammad-SAML-RBAC/Zammad-Jordan-Customer-Initial-Dashboard.png) · [Marcus Agent group permissions](Evidence/09-Zammad-SAML-RBAC/Zammad-Marcus-Agent-Group-Permissions.png) · [Detailed test record](Documentation/CHS-Zammad-SSO-RBAC-Test.md)

*Additional ticket-submission and agent-response screenshots were captured during the test; add sanitized copies to this evidence folder before linking them here.*

**What I learned:** Entra controls who can **authenticate** through SAML; Zammad controls what that user is **authorized** to do. An access review of Entra assignments alone would not recertify Zammad's local Agent/Admin roles.

## Diagnostic testing and control gaps

I also tested a **separate Entra SAML Toolkit application**: deliberately misconfigured its ACS URL, reproduced `AADSTS50011`, restored the correct URL, and confirmed successful sign-in. This test was **not** performed against the Zammad production-like integration. [Failure](Evidence/07-SAML-Federation/SAML-ACS-Mismatch-AADSTS50011.png) · [Recovery](Evidence/07-SAML-Federation/SAML-Authorized-SignIn.png)

| Control gap | Verified scope / remaining work |
| --- | --- |
| Broader baseline MFA and risk policies | **Report-only**; not claimed as enforced globally |
| Standing Global Administrator assignment | Identified; not remediated |
| Access review application | Decisions recorded; exported `Not applied` and separately verified final state |
| Cross-system access drift | Investigated manually after a SCIM lag; no scheduled drift detection |
| Zammad local Agent/Admin recertification | Role separation tested; no automated local-role access review |
| SCIM provisioning credential lifecycle | Integration operational; scheduled credential rotation not implemented |
| SAML Toolkit certificate rollover | Replacement staged; successful rollover not demonstrated |
| JML and UAR automation | Mover tested; no full HRIS-driven joiner/leaver flow or scheduled UAR export |

See the existing security standard, lifecycle SOP, operations runbook, and control assessment in [`Documentation/`](Documentation/). They describe configuration decisions and follow-up controls, not a production certification.

## The outcome

This wasn't just a set of Microsoft Entra screenshots. I followed the same access problem through **authentication, approval, provisioning, recertification, role changes, support, and audit evidence**. The key result was learning to distinguish a successful action in one system from a proven final state in another.

**Repository guide:** [`Architecture/`](Architecture/) shows the implemented identity flows; [`Evidence/README.md`](Evidence/README.md) indexes screenshots by business question; [`Automation/`](Automation/) contains the tested-scenario scripts and synthetic inputs; [`Documentation/`](Documentation/) contains controls and reconciliations; [`Demo/`](Demo/) contains walkthrough materials.

**Scope:** This is a simulated healthcare lab using fictional users and no patient data. It is **not** a production deployment, HIPAA compliance attestation, or formal certification assessment. Only the explicitly observed outcomes above are claimed as tested.
