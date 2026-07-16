@{
    RootModule        = 'AccessReviewLite.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '54d51863-b65e-4e79-8ef5-f3c638bdf0b9'
    Author            = 'Don Cook'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Don Cook. MIT License.'
    Description       = 'Read-only Microsoft Entra access review reporting with a tenant-free demo mode.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'ConvertTo-AccessReviewNormalizedData'
        'Get-AccessReviewAnalysis'
        'Import-AccessReviewDemoData'
        'Invoke-AccessReviewLite'
        'New-AccessReviewHtmlReport'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('MicrosoftGraph', 'Entra', 'Identity', 'Security', 'AccessReview')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/reveal79/access-review-lite'
        }
    }
}
