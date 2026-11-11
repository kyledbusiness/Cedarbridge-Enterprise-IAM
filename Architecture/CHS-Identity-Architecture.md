# Cedarbridge Health System | Identity architecture

One diagram shows the **implemented trust boundaries**. Solid paths represent configured or tested identity flows; dashed paths represent governance inputs and evidence. An access-review **decision** is not drawn as an automatic revocation.

```mermaid
flowchart TB
  Users["CHS workforce<br/>Jordan · Taylor · Marcus"]
  Admin["Sophia<br/>privileged admin"]
  Manager["Daniel / Marcus<br/>approvals & access reviews"]
  HR["Simulated HR move<br/>approval CSVs"]

  subgraph Entra["Microsoft Entra ID"]
    Auth["Workforce authentication<br/>Conditional Access"]
    PIM["PIM eligible role<br/>JIT activation"]
    Gov["Access package<br/>Access review decisions"]
    Groups["Group assignments<br/>Developer · Project Lead"]
  end

  subgraph Apps["Downstream applications"]
    GitHub["GitHub Enterprise Managed Users<br/>OIDC SSO"]
    Teams["GitHub users & teams<br/>SCIM · Write / Maintain RBAC"]
    Zammad["Zammad support desk<br/>SAML 2.0 SSO"]
    Roles["Local Zammad roles<br/>Customer · Agent · Admin"]
  end

  PS["Microsoft Graph PowerShell<br/>controlled mover"]
  Evidence["Sign-in, review, PowerShell,<br/>SCIM & application evidence"]

  Users --> Auth
  Admin --> PIM
  PIM --> Auth
  Manager -.-> Gov
  Gov -.-> Groups
  HR --> PS
  PS --> Groups
  Auth -->|OIDC sign-in| GitHub
  Groups -->|SCIM provisioning| Teams
  GitHub --> Teams
  Auth -->|SAML sign-in| Zammad
  Zammad --> Roles
  Groups -.-> Evidence
  Gov -.-> Evidence
  Teams -.-> Evidence
  Roles -.-> Evidence
```

**Important boundaries:** OIDC/SAML establishes authentication; SCIM synchronizes GitHub identities and groups; GitHub and Zammad enforce their own application permissions. Conditional Access has both enabled and Report-only policies. Review decisions were not demonstrated as automatically applied. The PowerShell mover required separate GitHub verification because SCIM propagation was asynchronous.
