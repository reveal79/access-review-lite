function Invoke-AccessReviewLite {
    [CmdletBinding(DefaultParameterSetName = 'Live')]
    param(
        [Parameter(ParameterSetName = 'Demo', Mandatory)][switch] $Demo,
        [Parameter(ParameterSetName = 'Live')][string] $TenantId,
        [Parameter(ParameterSetName = 'Live')][string] $ClientId,
        [Parameter(ParameterSetName = 'Live')][switch] $UseDeviceCode,
        [ValidateRange(1, 3650)][int] $StaleAdministratorDays = 90,
        [ValidateRange(1, 3650)][int] $StaleGuestDays = 180,
        [Parameter(Mandatory)][string] $OutputPath
    )

    $connected = $false
    try {
        if ($Demo) {
            $raw = Import-AccessReviewDemoData
        }
        else {
            $context = Connect-AccessReviewGraph -TenantId $TenantId -ClientId $ClientId -UseDeviceCode:$UseDeviceCode
            $connected = $true
            $raw = Get-LiveAccessReviewRawData -GraphContext $context
        }

        $normalized = ConvertTo-AccessReviewNormalizedData -InputObject $raw -StaleAdministratorDays $StaleAdministratorDays -StaleGuestDays $StaleGuestDays
        $analysis = Get-AccessReviewAnalysis -Data $normalized
        $reportPath = New-AccessReviewHtmlReport -Data $normalized -Analysis $analysis -OutputPath $OutputPath

        [pscustomobject]@{
            ReportPath = $reportPath
            Mode       = $normalized.Tenant.Mode
            Tenant     = $normalized.Tenant.DisplayName
            Findings   = $analysis.Counts
            Data       = $normalized
            Analysis   = $analysis
        }
    }
    finally {
        if ($connected -and (Get-Command Disconnect-MgGraph -ErrorAction SilentlyContinue)) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
