#requires -Version 7.2
[CmdletBinding(DefaultParameterSetName = 'Live')]
param(
    [Parameter(ParameterSetName = 'Demo', Mandatory)]
    [switch] $Demo,

    [Parameter(ParameterSetName = 'Live')]
    [string] $TenantId,

    [Parameter(ParameterSetName = 'Live')]
    [string] $ClientId,

    [Parameter(ParameterSetName = 'Live')]
    [switch] $UseDeviceCode,

    [ValidateRange(1, 3650)]
    [int] $StaleAdministratorDays = 90,

    [ValidateRange(1, 3650)]
    [int] $StaleGuestDays = 180,

    [string] $OutputPath = (Join-Path $PWD 'access-review-lite-report.html')
)

$modulePath = Join-Path $PSScriptRoot 'AccessReviewLite.psd1'
Import-Module $modulePath -Force

$parameters = @{
    OutputPath                = $OutputPath
    StaleAdministratorDays    = $StaleAdministratorDays
    StaleGuestDays            = $StaleGuestDays
}

if ($Demo) {
    $parameters.Demo = $true
}
else {
    if ($TenantId) { $parameters.TenantId = $TenantId }
    if ($ClientId) { $parameters.ClientId = $ClientId }
    if ($UseDeviceCode) { $parameters.UseDeviceCode = $true }
}

Invoke-AccessReviewLite @parameters
