function Get-ActivityStateLabel {
    param([string] $State)
    switch ($State) {
        'confirmed_active'                 { 'Confirmed active' }
        'confirmed_stale'                  { 'Confirmed stale' }
        'never_signed_in'                  { 'Never signed in' }
        'activity_unavailable_licensing'   { 'Unavailable - licensing' }
        'activity_unavailable_permissions' { 'Unavailable - permissions' }
        default                            { 'Activity unknown' }
    }
}

function ConvertTo-HtmlTableMarkup {
    param([object[]] $Items, [string[]] $Properties, [hashtable] $Labels)
    if (@($Items).Count -eq 0) { return '<tr><td colspan="20" class="empty">No records available.</td></tr>' }
    $rows = foreach ($item in $Items) {
        $cells = foreach ($property in $Properties) {
            $value = if ($Labels.ContainsKey($property)) { & $Labels[$property] $item } else { $item.$property }
            '<td>{0}</td>' -f (ConvertTo-HtmlEncoded $value)
        }
        '<tr>{0}</tr>' -f ($cells -join '')
    }
    return $rows -join [Environment]::NewLine
}

function New-AccessReviewHtmlReport {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][object] $Data,
        [Parameter(Mandatory)][object] $Analysis,
        [Parameter(Mandatory)][string] $OutputPath
    )

    $findingRows = ConvertTo-HtmlTableMarkup -Items $Analysis.Findings -Properties @('Severity','Title','Subject','Evidence','Recommendation') -Labels @{}
    $principalLabels = @{
        Roles = { param($x) $x.Roles -join ', ' }
        Activity = { param($x) Get-ActivityStateLabel $x.Activity.State }
        LastActivity = { param($x) if ($x.Activity.LastSignInDateTime) { $x.Activity.LastSignInDateTime } else { '-' } }
        MfaState = { param($x) $x.Mfa.State }
    }
    $adminRows = ConvertTo-HtmlTableMarkup -Items $Data.PrivilegedAccounts -Properties @('DisplayName','UserPrincipalName','Roles','AccountEnabled','Activity','LastActivity','MfaState') -Labels $principalLabels
    $guestRows = ConvertTo-HtmlTableMarkup -Items $Data.Guests -Properties @('DisplayName','UserPrincipalName','CreatedDateTime','AccountEnabled','Activity','LastActivity') -Labels $principalLabels
    $nonUserRows = ConvertTo-HtmlTableMarkup -Items $Data.NonUserPrivilegedPrincipals -Properties @('DisplayName','PrincipalType','Roles') -Labels @{ Roles = { param($x) $x.Roles -join ', ' } }
    $permissionRows = ConvertTo-HtmlTableMarkup -Items $Data.PermissionGrants -Properties @('ClientDisplayName','GrantType','Permission','ResourceDisplayName','ConsentType') -Labels @{}
    $metadataRows = ConvertTo-HtmlTableMarkup -Items $Data.CollectionMetadata -Properties @('Name','Status','RecordCount','ReasonCode','Reason') -Labels @{}

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Access Review Lite - $(ConvertTo-HtmlEncoded $Data.Tenant.DisplayName)</title>
<style>
:root{--ink:#172033;--muted:#617087;--line:#dce2ea;--panel:#fff;--bg:#f4f6f8;--critical:#a61b1b;--high:#b45309;--medium:#8a6400;--low:#2563a6;--info:#52647a;--brand:#155e75}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.5 Inter,Segoe UI,Arial,sans-serif}.wrap{max-width:1180px;margin:auto;padding:32px 22px 64px}header{background:#123247;color:#fff;padding:30px;border-radius:12px}h1{margin:0 0 6px;font-size:30px}h2{margin:0 0 14px;font-size:20px}h3{margin:0;font-size:15px}.subtitle{color:#d8e8ef;margin:0}.meta{margin-top:16px;color:#c5dbe5}.grid{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin:18px 0}.card,.section{background:var(--panel);border:1px solid var(--line);border-radius:10px}.card{padding:18px}.card strong{display:block;font-size:26px}.card span{color:var(--muted)}.section{margin-top:16px;padding:22px;overflow:auto}.notice{border-left:4px solid var(--brand);background:#edf7fa;padding:12px 14px;margin:14px 0}.critical{color:var(--critical)}.high{color:var(--high)}.medium{color:var(--medium)}.low{color:var(--low)}.informational{color:var(--info)}table{border-collapse:collapse;width:100%;min-width:760px}th,td{padding:10px 9px;text-align:left;vertical-align:top;border-bottom:1px solid var(--line)}th{font-size:12px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted);background:#fafbfc}.empty{text-align:center;color:var(--muted)}code{background:#edf1f5;padding:2px 5px;border-radius:4px}.footer{color:var(--muted);margin-top:22px;font-size:12px}@media(max-width:800px){.grid{grid-template-columns:repeat(2,1fr)}header{border-radius:0}.wrap{padding:0 0 40px}.section,.grid{margin-left:12px;margin-right:12px}}@media print{body{background:#fff}.wrap{max-width:none;padding:0}.section,.card,header{break-inside:avoid;box-shadow:none}.section{overflow:visible}table{min-width:0;font-size:10px}.grid{grid-template-columns:repeat(5,1fr)}}
</style>
</head>
<body><main class="wrap">
<header><h1>Access Review Lite</h1><p class="subtitle">Read-only identity and application-permission review</p><div class="meta">$(ConvertTo-HtmlEncoded $Data.Tenant.DisplayName) | $(ConvertTo-HtmlEncoded $Data.Tenant.Mode) mode | Generated $(ConvertTo-HtmlEncoded $Data.GeneratedAt)</div></header>
<section class="grid" aria-label="Finding summary">
<div class="card"><strong class="critical">$($Analysis.Counts.Critical)</strong><span>Critical</span></div>
<div class="card"><strong class="high">$($Analysis.Counts.High)</strong><span>High</span></div>
<div class="card"><strong class="medium">$($Analysis.Counts.Medium)</strong><span>Medium</span></div>
<div class="card"><strong class="low">$($Analysis.Counts.Low)</strong><span>Low</span></div>
<div class="card"><strong class="informational">$($Analysis.Counts.Informational)</strong><span>Informational</span></div>
</section>
<section class="section"><h2>Executive summary</h2><p>This assessment identified <strong>$($Analysis.Counts.Total)</strong> review findings across privileged identities, guests, and application permissions. Findings are evidence-based and severity is assigned by transparent rules. Missing or inaccessible data is never converted into a risk finding.</p><div class="notice"><strong>Interpretation:</strong> "Unavailable" describes collection coverage, not risk. Review Collection metadata before drawing conclusions from an empty section.</div></section>
<section class="section"><h2>Findings</h2><table><thead><tr><th>Severity</th><th>Finding</th><th>Subject</th><th>Evidence</th><th>Recommendation</th></tr></thead><tbody>$findingRows</tbody></table></section>
<section class="section"><h2>Privileged accounts</h2><table><thead><tr><th>Name</th><th>User principal name</th><th>Roles</th><th>Enabled</th><th>Activity state</th><th>Last activity</th><th>MFA state</th></tr></thead><tbody>$adminRows</tbody></table></section>
<section class="section"><h2>Non-user privileged principals</h2><p>Group membership expansion and PIM-eligible assignments are deferred from v0.1.0.</p><table><thead><tr><th>Name</th><th>Principal type</th><th>Roles</th></tr></thead><tbody>$nonUserRows</tbody></table></section>
<section class="section"><h2>Guest access</h2><table><thead><tr><th>Name</th><th>User principal name</th><th>Created</th><th>Enabled</th><th>Activity state</th><th>Last activity</th></tr></thead><tbody>$guestRows</tbody></table></section>
<section class="section"><h2>Application and delegated permissions</h2><table><thead><tr><th>Client</th><th>Grant type</th><th>Permission</th><th>Resource</th><th>Consent</th></tr></thead><tbody>$permissionRows</tbody></table></section>
<section class="section"><h2>Collection metadata</h2><table><thead><tr><th>Dataset</th><th>Status</th><th>Records</th><th>Reason code</th><th>Reason</th></tr></thead><tbody>$metadataRows</tbody></table></section>
<section class="section"><h2>Methodology and limitations</h2><ul><li>Stale administrator threshold: $($Data.Thresholds.StaleAdministratorDays) days.</li><li>Stale guest threshold: $($Data.Thresholds.StaleGuestDays) days.</li><li>Activity states distinguish confirmed active, confirmed stale, never signed in, licensing unavailable, permission unavailable, and unknown.</li><li>Only active role assignments are included. PIM eligibility and group-membership expansion are deferred.</li><li>Permission severity comes from the versioned <code>config/risk-permissions.json</code> catalog.</li><li>This report is review evidence, not proof that access should automatically be removed.</li></ul></section>
<p class="footer">Generated by Access Review Lite v0.1.0. All tenant collection is read-only.</p>
</main></body></html>
"@

    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Write standalone access review HTML report')) {
        [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutputPath), $html, [System.Text.UTF8Encoding]::new($false))
    }
    return [System.IO.Path]::GetFullPath($OutputPath)
}
