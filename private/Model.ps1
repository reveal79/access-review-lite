function Resolve-ActivityState {
    [CmdletBinding()]
    param(
        [AllowNull()][object] $LastSignInDateTime,
        [bool] $NeverSignedIn,
        [string] $UnavailableReasonCode,
        [int] $StaleAfterDays,
        [DateTimeOffset] $AsOf
    )

    if ($UnavailableReasonCode) {
        return Get-ActivityUnavailableState -ReasonCode $UnavailableReasonCode
    }
    if ($NeverSignedIn) { return 'never_signed_in' }

    $lastSignIn = ConvertTo-UtcDateTime $LastSignInDateTime
    if ($null -eq $lastSignIn) { return 'activity_unknown' }
    if ($lastSignIn -lt $AsOf.AddDays(-$StaleAfterDays)) { return 'confirmed_stale' }
    return 'confirmed_active'
}

function ConvertTo-NormalizedPrincipal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $InputObject,
        [Parameter(Mandatory)][ValidateSet('Administrator', 'Guest')][string] $Kind,
        [Parameter(Mandatory)][int] $StaleAfterDays,
        [Parameter(Mandatory)][DateTimeOffset] $AsOf
    )

    $activity = $InputObject.Activity
    $state = Resolve-ActivityState `
        -LastSignInDateTime $activity.LastSignInDateTime `
        -NeverSignedIn ([bool]$activity.NeverSignedIn) `
        -UnavailableReasonCode ([string]$activity.UnavailableReasonCode) `
        -StaleAfterDays $StaleAfterDays `
        -AsOf $AsOf

    [pscustomobject]@{
        Id             = [string]$InputObject.Id
        Kind           = $Kind
        DisplayName    = [string]$InputObject.DisplayName
        UserPrincipalName = [string]$InputObject.UserPrincipalName
        AccountEnabled = if ($null -eq $InputObject.AccountEnabled) { $null } else { [bool]$InputObject.AccountEnabled }
        CreatedDateTime = if ($InputObject.CreatedDateTime) { (ConvertTo-UtcDateTime $InputObject.CreatedDateTime).ToString('o') } else { $null }
        Roles          = @($InputObject.Roles | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        Activity       = [pscustomobject]@{
            State              = $state
            LastSignInDateTime = if ($activity.LastSignInDateTime) { (ConvertTo-UtcDateTime $activity.LastSignInDateTime).ToString('o') } else { $null }
            Reason             = [string]$activity.Reason
        }
        Mfa            = [pscustomobject]@{
            State  = if ($InputObject.Mfa.State) { [string]$InputObject.Mfa.State } else { 'Unknown' }
            Reason = [string]$InputObject.Mfa.Reason
        }
    }
}

function ConvertTo-AccessReviewNormalizedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][object] $InputObject,
        [ValidateRange(1, 3650)][int] $StaleAdministratorDays = 90,
        [ValidateRange(1, 3650)][int] $StaleGuestDays = 180,
        [DateTimeOffset] $AsOf = [DateTimeOffset]::UtcNow
    )

    process {
        $administrators = @($InputObject.PrivilegedAccounts | ForEach-Object {
            ConvertTo-NormalizedPrincipal -InputObject $_ -Kind Administrator -StaleAfterDays $StaleAdministratorDays -AsOf $AsOf
        })
        $guests = @($InputObject.Guests | ForEach-Object {
            ConvertTo-NormalizedPrincipal -InputObject $_ -Kind Guest -StaleAfterDays $StaleGuestDays -AsOf $AsOf
        })

        [pscustomobject]@{
            SchemaVersion = '1.0'
            GeneratedAt   = $AsOf.ToString('o')
            Tenant        = [pscustomobject]@{
                Id          = [string]$InputObject.Tenant.Id
                DisplayName = [string]$InputObject.Tenant.DisplayName
                Mode        = [string]$InputObject.Tenant.Mode
            }
            Thresholds    = [pscustomobject]@{
                StaleAdministratorDays = $StaleAdministratorDays
                StaleGuestDays         = $StaleGuestDays
            }
            CollectionMetadata = @($InputObject.CollectionMetadata)
            PrivilegedAccounts = $administrators
            NonUserPrivilegedPrincipals = @($InputObject.NonUserPrivilegedPrincipals)
            Guests        = $guests
            PermissionGrants = @($InputObject.PermissionGrants | ForEach-Object {
                [pscustomobject]@{
                    Id                 = [string]$_.Id
                    ClientId           = [string]$_.ClientId
                    ClientDisplayName  = [string]$_.ClientDisplayName
                    ResourceId         = [string]$_.ResourceId
                    ResourceDisplayName = [string]$_.ResourceDisplayName
                    Permission         = [string]$_.Permission
                    GrantType          = [string]$_.GrantType
                    ConsentType        = [string]$_.ConsentType
                }
            })
        }
    }
}

function Import-AccessReviewDemoData {
    [CmdletBinding()]
    param([string] $Path = (Join-Path $script:ModuleRoot 'demo/northwind-tenant.json'))

    if (-not (Test-Path -LiteralPath $Path)) { throw "Demo data was not found: $Path" }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 20
}
