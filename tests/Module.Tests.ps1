Describe 'Module quality gate' {
    It 'imports and exports the supported public commands' {
        $modulePath = Join-Path $PSScriptRoot '../AccessReviewLite.psd1'
        $module = Import-Module $modulePath -Force -PassThru
        $module.ExportedFunctions.Keys | Should -Contain 'Invoke-AccessReviewLite'
        $module.ExportedFunctions.Keys | Should -Contain 'ConvertTo-AccessReviewNormalizedData'
        $module.ExportedFunctions.Keys | Should -Contain 'Get-AccessReviewAnalysis'
        $module.ExportedFunctions.Keys | Should -Contain 'New-AccessReviewHtmlReport'
    }

    It 'has a valid module manifest' {
        $manifest = Test-ModuleManifest (Join-Path $PSScriptRoot '../AccessReviewLite.psd1')
        $manifest.Version.ToString() | Should -Be '0.1.0'
    }
}
