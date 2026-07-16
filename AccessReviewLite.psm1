Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = $PSScriptRoot

@(
    'private/Utilities.ps1'
    'private/Model.ps1'
    'private/Analysis.ps1'
    'private/Graph/GraphClient.ps1'
    'private/Graph/Collectors.ps1'
    'private/Reporting/HtmlReport.ps1'
    'public/Invoke-AccessReview.ps1'
) | ForEach-Object {
    . (Join-Path $PSScriptRoot $_)
}

Export-ModuleMember -Function @(
    'ConvertTo-AccessReviewNormalizedData'
    'Get-AccessReviewAnalysis'
    'Import-AccessReviewDemoData'
    'Invoke-AccessReviewLite'
    'New-AccessReviewHtmlReport'
)
