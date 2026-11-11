# Evidence guide | Cedarbridge Enterprise IAM

This folder contains **sanitized lab screenshots and exported review evidence**. Read them alongside the [project story](../README.md). The screenshots document different controls; they do not imply all related events happened automatically or at the same time.

## Follow the access lifecycle

| Question | Evidence folder | Suggested starting evidence |
| --- | --- | --- |
| **How are sign-ins and privileged actions controlled?** | [`01-Conditional-Access/`](01-Conditional-Access/) and [`02-Privileged-Access/`](02-Privileged-Access/) | [CA policies](01-Conditional-Access/CA-Policies-Overview.png) · [PIM activation](02-Privileged-Access/PIM-CloudAppAdmin-Successful-Activation.png) |
| **How do CHS users reach GitHub, and what permissions do they get?** | [`03-OIDC-SCIM/`](03-OIDC-SCIM/) | [SCIM provisioning](03-OIDC-SCIM/GitHub-SCIM-Provisioning-Overview.png) · [Team RBAC](03-OIDC-SCIM/GitHub-Team-Repository-Permissions.png) |
| **Who approved Taylor's access?** | [`04-Entitlement-Management/`](04-Entitlement-Management/) | [Access-package approval](04-Entitlement-Management/Access-Package-Approval-Success.png) |
| **Did Taylor still need that access?** | [`05-Access-Reviews/`](05-Access-Reviews/) | [Review decisions](05-Access-Reviews/Access-Review-Individual-Results.png) · [Decision reconciliation CSV](05-Access-Reviews/CHS-UAR-Decision-Reconciliation.csv) · [Entra final group](05-Access-Reviews/UAR-Entra-Developer-Group-All-Members.png) · [GitHub final team](05-Access-Reviews/UAR-GitHub-Developer-Team-Final-State.png) |
| **Did Jordan's old role actually disappear in GitHub?** | [`06-JML-Automation/`](06-JML-Automation/) | [Final-state check](06-JML-Automation/JML-Mover-Final-State-Validation.png) · [Downstream removal audit](06-JML-Automation/Jordan-GitHub-SCIM-Member-Removal.png) |
| **How was a separate SAML error diagnosed?** | [`07-SAML-Federation/`](07-SAML-Federation/) | [Intentional ACS error](07-SAML-Federation/SAML-ACS-Mismatch-AADSTS50011.png) · [Restored sign-in](07-SAML-Federation/SAML-Authorized-SignIn.png) |
| **What risks remain?** | [`08-Security-Assessment/`](08-Security-Assessment/) | Supporting security assessments and exception evidence |
| **Can users sign in to Zammad without gaining agent privileges?** | [`09-Zammad-SAML-RBAC/`](09-Zammad-SAML-RBAC/) | [SSO option](09-Zammad-SAML-RBAC/Zammad-CHS-Employee-SSO-Login.png) · [Jordan Customer view](09-Zammad-SAML-RBAC/Zammad-Jordan-Customer-Initial-Dashboard.png) · [Marcus group permissions](09-Zammad-SAML-RBAC/Zammad-Marcus-Agent-Group-Permissions.png) |

## How to interpret the review evidence

- The review export recorded **Approve** for Jordan and **Deny** for Taylor, both with **Apply Result = Not applied**.
- Taylor's access-package assignment was revoked **separately**; Jordan's Developer removal occurred during a **later mover workflow**.
- Entra `SG-CHS-GH-Developers` and GitHub's linked Developer team both showed **zero members at final verification**. These snapshots demonstrate state, not the exact removal time or cause.
- See the separate [UAR audit reconciliation](../Documentation/CHS-UAR-Audit-Reconciliation.md) for scope and limitations.

## Additional evidence to add

Two screenshots captured separately during the Zammad ticket test are not bundled here yet. After redacting personal information, save them in `09-Zammad-SAML-RBAC/` as:

- `Zammad-Jordan-Customer-Ticket-Submitted.png`
- `Zammad-Marcus-Agent-Ticket-Response.png`

Do not publish live user identifiers, access tokens, private keys, or unsanitized exports. Keep original unredacted audit files outside the public repository.
