$script:RequiredGraphScopes = @(
    'User.Read.All'
    'AuditLog.Read.All'
    'Reports.Read.All'
    'RoleManagement.Read.Directory'
    'Application.Read.All'
    'Directory.Read.All'
)

function Connect-AccessReviewGraph {
    [CmdletBinding()]
    param(
        [string] $TenantId,
        [string] $ClientId,
        [switch] $UseDeviceCode
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw 'Microsoft.Graph.Authentication is required for live mode. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $connect = @{
        Scopes       = $script:RequiredGraphScopes
        ContextScope = 'Process'
        NoWelcome    = $true
        ErrorAction  = 'Stop'
    }
    if ($TenantId) { $connect.TenantId = $TenantId }
    if ($ClientId) { $connect.ClientId = $ClientId }
    if ($UseDeviceCode) { $connect.UseDeviceCode = $true }

    Connect-MgGraph @connect | Out-Null
    $context = Get-MgContext
    if ($null -eq $context) { throw 'Microsoft Graph authentication completed without an available context.' }
    return $context
}

function Invoke-GraphPagedRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Uri)

    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    while ($nextLink) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink -OutputType PSObject -ErrorAction Stop
        if ($response.PSObject.Properties.Name -contains 'value') {
            foreach ($item in @($response.value)) { $items.Add($item) }
        }
        else {
            $items.Add($response)
        }
        $nextLink = if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            [string]$response.'@odata.nextLink'
        }
        else { $null }
    }
    return @($items)
}

function Invoke-OptionalGraphDataset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][scriptblock] $Collector
    )

    try {
        $records = @(& $Collector)
        [pscustomobject]@{
            Records  = $records
            Metadata = Get-CollectionMetadataRecord -Name $Name -Status Available -RecordCount $records.Count
        }
    }
    catch {
        $failure = Get-CollectionFailure -ErrorRecord $_
        [pscustomobject]@{
            Records  = @()
            Metadata = Get-CollectionMetadataRecord -Name $Name -Status Unavailable -ReasonCode $failure.ReasonCode -Reason $failure.Reason
        }
    }
}
