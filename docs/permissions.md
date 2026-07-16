# Microsoft Graph permissions and directory roles

Access Review Lite uses delegated, read-only permissions. Admin consent may be required. Microsoft Graph evaluates both OAuth scopes and the signed-in user's directory role. There is no claim that one directory role universally guarantees access to every dataset.

| Dataset | Endpoint | Delegated scope used | Microsoft-documented role examples |
|---|---|---|---|
| Directory users and guests | `/users` | `User.Read.All` | Directory Readers, User Administrator, or another supported role depending on returned properties |
| Sign-in activity | `/users?$select=signInActivity` | `AuditLog.Read.All`, `User.Read.All` | Reports Reader, Security Reader, or another role supported by the endpoint; Entra P1/P2 is also required |
| MFA registration | `/reports/authenticationMethods/userRegistrationDetails` | `AuditLog.Read.All` is Microsoft Graph's documented least-privileged scope; this tool additionally requests `Reports.Read.All` | Reports Reader, Security Reader, Security Administrator, Global Reader, or a supported custom role |
| Active role assignments | `/roleManagement/directory/roleAssignments` | `RoleManagement.Read.Directory` | Directory Readers, Global Reader, or Privileged Role Administrator |
| Service principals and app roles | `/servicePrincipals` and `/servicePrincipals/{id}/appRoleAssignments` | `Application.Read.All` | Directory Readers, Application Administrator, Cloud Application Administrator, or another supported role |
| Delegated consent grants | `/oauth2PermissionGrants` | `Directory.Read.All` | Directory Readers, Application Administrator, Cloud Application Administrator, or another supported role |

Role requirements can change and vary by endpoint and tenant configuration. Consult current Microsoft Graph documentation before production use. When a dataset returns an authorization error, the report marks it unavailable, records the reason, and continues.

The `signInActivity` property requires Microsoft Entra ID P1 or P2 and `AuditLog.Read.All`. A missing sign-in timestamp is not, by itself, proof that an account never signed in. Authentication-method registration report availability can also depend on tenant licensing and the signed-in user's supported directory role.

`Reports.Read.All` is included by project policy for MFA-reporting compatibility, but Microsoft currently documents `AuditLog.Read.All`, not `Reports.Read.All`, as the least-privileged permission for `userRegistrationDetails`.

## Requested scopes

```text
User.Read.All
AuditLog.Read.All
Reports.Read.All
RoleManagement.Read.Directory
Application.Read.All
Directory.Read.All
```

No write permission is requested.
