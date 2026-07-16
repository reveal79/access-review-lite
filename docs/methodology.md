# Methodology

Access Review Lite separates collection coverage from risk analysis. Each optional dataset is collected independently and recorded as `Available`, `Partial`, or `Unavailable`. An authorization, licensing, or API failure does not terminate other collectors.

## Activity states

| Normalized state | Meaning |
|---|---|
| `confirmed_active` | A successful sign-in exists inside the configured threshold. |
| `confirmed_stale` | A successful sign-in exists outside the configured threshold. |
| `never_signed_in` | Available source data explicitly confirms no sign-in. |
| `activity_unavailable_licensing` | Licensing prevented activity collection. |
| `activity_unavailable_permissions` | Authorization prevented activity collection. |
| `activity_unknown` | Evidence is insufficient to classify activity. |

Missing activity is not assumed to mean "never signed in." Microsoft Graph can omit sign-in activity for historical, licensing, and authorization reasons.

## Default rules

| Condition | Severity |
|---|---|
| Disabled privileged account | Critical |
| Privileged account confirmed without MFA registration | Critical |
| Confirmed stale privileged account | High |
| Privileged account confirmed never signed in | High |
| Confirmed stale guest | Medium |
| Old guest confirmed never signed in | Medium |
| Old guest with unavailable or unknown activity | Informational review |
| Cataloged application or delegated permission | Defined by the versioned permission catalog |

Defaults are 90 days for privileged administrators and 180 days for guests. Permission severity is stored in `config/risk-permissions.json`; no proprietary or identity score is generated.

## v0.1.0 limitations

- Active Entra role assignments only.
- No PIM-eligible assignment collection.
- No expansion of group-based role membership.
- Global Microsoft cloud only.
- The report supports review decisions but does not remediate access.
