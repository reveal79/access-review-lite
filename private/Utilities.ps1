function ConvertTo-HtmlEncoded {
    [CmdletBinding()]
    param([AllowNull()][object] $Value)

    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-UtcDateTime {
    [CmdletBinding()]
    param([AllowNull()][object] $Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse([string]$Value, [ref]$parsed)) {
        return $parsed.ToUniversalTime()
    }
    return $null
}

function Get-CollectionMetadataRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][ValidateSet('Available', 'Partial', 'Unavailable')][string] $Status,
        [string] $ReasonCode,
        [string] $Reason,
        [int] $RecordCount = 0
    )

    [pscustomobject]@{
        Name        = $Name
        Status      = $Status
        ReasonCode  = $ReasonCode
        Reason      = $Reason
        RecordCount = $RecordCount
        CollectedAt = [DateTimeOffset]::UtcNow.ToString('o')
    }
}

function Get-CollectionFailure {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord] $ErrorRecord)

    $message = $ErrorRecord.Exception.Message
    $statusCode = $null
    if ($ErrorRecord.Exception.PSObject.Properties.Name -contains 'ResponseStatusCode') {
        $statusCode = [int]$ErrorRecord.Exception.ResponseStatusCode
    }

    if ($statusCode -eq 401 -or $statusCode -eq 403 -or $message -match 'Authorization_RequestDenied|Insufficient privileges|Forbidden') {
        return [pscustomobject]@{ ReasonCode = 'PermissionDenied'; Reason = $message }
    }
    if ($statusCode -eq 402 -or $message -match 'license|licensing|premium') {
        return [pscustomobject]@{ ReasonCode = 'LicenseUnavailable'; Reason = $message }
    }
    return [pscustomobject]@{ ReasonCode = 'CollectionError'; Reason = $message }
}

function Get-ActivityUnavailableState {
    [CmdletBinding()]
    param([string] $ReasonCode)

    switch ($ReasonCode) {
        'PermissionDenied'   { 'activity_unavailable_permissions' }
        'LicenseUnavailable' { 'activity_unavailable_licensing' }
        default              { 'activity_unknown' }
    }
}
