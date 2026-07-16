function Import-PermissionRiskCatalog {
    [CmdletBinding()]
    param([string] $Path = (Join-Path $script:ModuleRoot 'config/risk-permissions.json'))

    $catalog = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 10
    $lookup = @{}
    foreach ($entry in $catalog.Permissions) {
        $lookup[$entry.Name.ToLowerInvariant()] = $entry
    }
    return $lookup
}

function Get-AccessReviewFindingRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RuleId,
        [Parameter(Mandatory)][ValidateSet('Critical', 'High', 'Medium', 'Low', 'Informational')][string] $Severity,
        [Parameter(Mandatory)][string] $Category,
        [Parameter(Mandatory)][string] $Title,
        [Parameter(Mandatory)][string] $Subject,
        [Parameter(Mandatory)][string] $Evidence,
        [Parameter(Mandatory)][string] $Recommendation
    )

    [pscustomobject]@{
        RuleId        = $RuleId
        Severity      = $Severity
        Category      = $Category
        Title         = $Title
        Subject       = $Subject
        Evidence      = $Evidence
        Recommendation = $Recommendation
    }
}

function Get-AccessReviewAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][object] $Data,
        [string] $PermissionCatalogPath = (Join-Path $script:ModuleRoot 'config/risk-permissions.json')
    )

    process {
        $findings = [System.Collections.Generic.List[object]]::new()

        foreach ($admin in $Data.PrivilegedAccounts) {
            $subject = if ($admin.UserPrincipalName) { $admin.UserPrincipalName } else { $admin.DisplayName }
            if ($admin.AccountEnabled -eq $false) {
                $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-ADMIN-001' -Severity Critical -Category 'Privileged access' -Title 'Disabled privileged account' -Subject $subject -Evidence "Disabled account retains: $($admin.Roles -join ', ')." -Recommendation 'Remove privileged assignments or document the required exception.'))
            }
            if ($admin.Mfa.State -eq 'NotRegistered') {
                $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-ADMIN-002' -Severity Critical -Category 'Authentication' -Title 'Privileged account without MFA registration' -Subject $subject -Evidence 'The authentication-methods registration dataset confirms MFA is not registered.' -Recommendation 'Require and verify an approved strong authentication method.'))
            }
            if ($admin.Activity.State -eq 'confirmed_stale') {
                $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-ADMIN-003' -Severity High -Category 'Privileged access' -Title 'Confirmed stale privileged account' -Subject $subject -Evidence "Last successful sign-in: $($admin.Activity.LastSignInDateTime)." -Recommendation 'Validate continued need and remove or reduce standing privilege.'))
            }
            elseif ($admin.Activity.State -eq 'never_signed_in') {
                $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-ADMIN-004' -Severity High -Category 'Privileged access' -Title 'Privileged account has never signed in' -Subject $subject -Evidence 'Available activity data confirms no successful sign-in.' -Recommendation 'Validate ownership and business need before retaining the assignment.'))
            }
        }

        $asOf = ConvertTo-UtcDateTime $Data.GeneratedAt
        foreach ($guest in $Data.Guests) {
            $subject = if ($guest.UserPrincipalName) { $guest.UserPrincipalName } else { $guest.DisplayName }
            if ($guest.Activity.State -eq 'confirmed_stale') {
                $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-GUEST-001' -Severity Medium -Category 'Guest access' -Title 'Confirmed stale guest account' -Subject $subject -Evidence "Last successful sign-in: $($guest.Activity.LastSignInDateTime)." -Recommendation 'Ask the sponsor to recertify access or remove the guest.'))
            }
            elseif ($guest.Activity.State -eq 'never_signed_in') {
                $created = ConvertTo-UtcDateTime $guest.CreatedDateTime
                if ($created -and $created -lt $asOf.AddDays(-$Data.Thresholds.StaleGuestDays)) {
                    $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-GUEST-002' -Severity Medium -Category 'Guest access' -Title 'Old guest account has never signed in' -Subject $subject -Evidence "Created $($guest.CreatedDateTime); available activity confirms no sign-in." -Recommendation 'Validate the invitation and remove it if no longer required.'))
                }
            }
            elseif ($guest.Activity.State -in @('activity_unavailable_licensing', 'activity_unavailable_permissions', 'activity_unknown')) {
                $created = ConvertTo-UtcDateTime $guest.CreatedDateTime
                if ($created -and $created -lt $asOf.AddDays(-$Data.Thresholds.StaleGuestDays)) {
                    $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-GUEST-003' -Severity Informational -Category 'Guest access' -Title 'Old guest requires manual review' -Subject $subject -Evidence "Created $($guest.CreatedDateTime); activity state is $($guest.Activity.State), so staleness is not asserted." -Recommendation 'Review the guest with its sponsor; do not treat missing activity as evidence of inactivity.'))
                }
            }
        }

        $catalog = Import-PermissionRiskCatalog -Path $PermissionCatalogPath
        foreach ($grant in $Data.PermissionGrants) {
            $key = $grant.Permission.ToLowerInvariant()
            if ($catalog.ContainsKey($key)) {
                $risk = $catalog[$key]
                $findings.Add((Get-AccessReviewFindingRecord -RuleId 'ARL-APP-001' -Severity $risk.Severity -Category 'Application permissions' -Title "High-risk $($grant.GrantType.ToLowerInvariant()) permission" -Subject $grant.ClientDisplayName -Evidence "$($grant.Permission) on $($grant.ResourceDisplayName). Catalog rationale: $($risk.Rationale)" -Recommendation $risk.Recommendation))
            }
        }

        $severityOrder = @{ Critical = 0; High = 1; Medium = 2; Low = 3; Informational = 4 }
        $ordered = @($findings | Sort-Object @{ Expression = { $severityOrder[$_.Severity] } }, Category, Subject)
        [pscustomobject]@{
            Findings = $ordered
            Counts   = [pscustomobject]@{
                Critical      = @($ordered | Where-Object Severity -eq Critical).Count
                High          = @($ordered | Where-Object Severity -eq High).Count
                Medium        = @($ordered | Where-Object Severity -eq Medium).Count
                Low           = @($ordered | Where-Object Severity -eq Low).Count
                Informational = @($ordered | Where-Object Severity -eq Informational).Count
                Total         = $ordered.Count
            }
        }
    }
}
