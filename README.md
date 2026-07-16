# Access Review Lite

Access Review Lite is a PowerShell-based, read-only Microsoft Entra review tool for privileged accounts, stale administrators, guest access, and high-risk application permissions. It generates one portable HTML report and includes a tenant-free demo mode.

The project favors explainable evidence over a proprietary score. Missing data is displayed as unavailable or unknown and is never silently converted into a risk finding.

## Highlights

- Active privileged-role assignments and disabled privileged accounts
- Six distinct sign-in activity states
- MFA-registration findings only when the dataset confirms the condition
- Guest inactivity review with conservative handling of missing activity
- App-only role assignments and delegated OAuth grants
- Transparent, versioned permission-risk catalog
- Independent collectors that continue after optional-dataset failures
- Standalone HTML with no external scripts, fonts, or stylesheets
- Synthetic demo mode with no login or tenant access

## Requirements

- PowerShell 7.2 or newer
- `Microsoft.Graph.Authentication` for live mode only
- A work or school account with appropriate consent and endpoint-specific directory roles

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Try the demo

```powershell
./Invoke-AccessReviewLite.ps1 -Demo -OutputPath ./reports/demo.html
```

Demo mode performs no authentication or network requests.

[View the synthetic sample report](docs/sample-report.html).

## Run a live review

```powershell
./Invoke-AccessReviewLite.ps1 -TenantId '<tenant-id>' -UseDeviceCode -OutputPath ./reports/tenant-review.html
```

For tighter enterprise-app isolation, supply a custom public-client application ID with `-ClientId`. Authentication is process-scoped and disconnected when collection finishes.

Requested delegated scopes:

```text
User.Read.All
AuditLog.Read.All
Reports.Read.All
RoleManagement.Read.Directory
Application.Read.All
Directory.Read.All
```

All are read-only. `Reports.Read.All` is requested in addition to the endpoint-specific least-privileged scopes; see [permissions, licensing, and directory-role notes](docs/permissions.md).

## Resilient collection

Authorization, licensing, or API failures are handled per dataset. Other collectors continue, affected report sections are marked `Unavailable` or `Partial`, and collection metadata records the reason. Missing data does not generate risk findings.

Activity values are normalized as:

- Confirmed active
- Confirmed stale
- Never signed in
- Unavailable due to licensing
- Unavailable due to permissions
- Unknown

## Default rules

- Stale administrator: 90 days
- Stale guest: 180 days
- Disabled privileged account: Critical
- Privileged account confirmed without MFA registration: Critical
- Confirmed stale privileged account: High
- Old guest with unavailable activity: Informational review only
- Application permission severity: `config/risk-permissions.json`

See the complete [methodology and limitations](docs/methodology.md).

## Quality checks

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning
Invoke-Pester -Path ./tests -CI
./Invoke-AccessReviewLite.ps1 -Demo -OutputPath ./artifacts/access-review-lite-demo.html
```

GitHub Actions runs these checks on Windows and Linux.

## v0.1.0 boundaries

Deferred:

- PIM-eligible assignments
- Group-membership expansion
- Sovereign clouds
- Identity scoring
- Remediation or write operations

## Privacy and safety

Live mode sends read-only queries directly to Microsoft Graph. Report files can contain sensitive identity and authorization data; store and share them appropriately. Demo mode contains synthetic identities only.

## License

MIT (c) 2026 Don Cook. See [LICENSE](LICENSE).
