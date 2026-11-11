# CHS Support Desk — Zammad SAML & RBAC Verification

**Application:** CHS - Clinic Integration Support Desk (Zammad)  
**Identity provider:** Microsoft Entra ID (SAML 2.0)  
**Population:** Fictional CHS test identities

## Scenario

Jordan, now a Project Lead, submits an EHR integration access issue. Marcus, a support Agent, claims and responds to the ticket. This tests application-local role separation after SAML authentication; no live clinical system entitlement changes were performed.

## Observed checks

| Control | Evidence / result |
| --- | --- |
| SAML sign-in | Jordan authenticated via CHS Employee SSO; Entra interactive application sign-in showed Success |
| Entra sign-in policy evaluation | Relevant Conditional Access and report-only policy results were inspected. MFA outcome is not asserted without the matching Authentication Details evidence |
| Customer authorization | Jordan could create and view his own tickets, without agent ticket-management functions |
| Agent authorization | Marcus was configured as Agent with Full permission on the Zammad `Users` ticket group and reportedly assigned/responded to Jordan's ticket |
| Local administrator | Original Zammad administrator retained for recovery; not proof of central privileged-account governance |
| Transient error | Initial SAML button click triggered HTTP 422 `InvalidAuthenticityToken`; retry and further attempts worked. Root cause unconfirmed |

## Evidence available in this update

- [CHS SSO login option](../Evidence/09-Zammad-SAML-RBAC/Zammad-CHS-Employee-SSO-Login.png)
- [Jordan Customer dashboard before the ticket test](../Evidence/09-Zammad-SAML-RBAC/Zammad-Jordan-Customer-Initial-Dashboard.png)
- [Marcus Agent group permission configuration](../Evidence/09-Zammad-SAML-RBAC/Zammad-Marcus-Agent-Group-Permissions.png)

**Additional author-held screenshots to publish (not included in this update):** Jordan's submitted ticket and Marcus's ticket owner/response view, preferably with test-person identifiers and message content sanitized. These strengthen the behavioral result beyond configuration evidence.

## Authorization boundary

**Entra:** Authenticates CHS workforce identities and limits enterprise-application assignments.  
**Zammad:** Controls Customer, Agent, and Admin role privileges and ticket-group access. These local roles were not automatically mapped, provisioned, or periodically recertified through Entra in this lab.
