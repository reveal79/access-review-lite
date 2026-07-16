BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../AccessReviewLite.psd1'
    Import-Module $modulePath -Force
    $raw = Import-AccessReviewDemoData
    $script:data = ConvertTo-AccessReviewNormalizedData -InputObject $raw -AsOf ([DateTimeOffset]'2026-07-15T17:00:00Z')
    $script:analysis = Get-AccessReviewAnalysis -Data $data
}

Describe 'Standalone HTML report' {
    It 'renders every activity state and collection metadata' {
        $path = Join-Path $TestDrive 'report.html'
        New-AccessReviewHtmlReport -Data $data -Analysis $analysis -OutputPath $path | Should -Be $path
        $html = Get-Content -LiteralPath $path -Raw
        $html | Should -Match 'Confirmed active'
        $html | Should -Match 'Confirmed stale'
        $html | Should -Match 'Never signed in'
        $html | Should -Match 'Unavailable - licensing'
        $html | Should -Match 'Unavailable - permissions'
        $html | Should -Match 'Activity unknown'
        $html | Should -Match 'Collection metadata'
        $html | Should -Not -Match '<script src='
        $html | Should -Not -Match '<link rel='
    }

    It 'HTML-encodes tenant-controlled values' {
        $data.Tenant.DisplayName = '<script>alert(1)</script>'
        $path = Join-Path $TestDrive 'encoded.html'
        New-AccessReviewHtmlReport -Data $data -Analysis $analysis -OutputPath $path | Out-Null
        $html = Get-Content -LiteralPath $path -Raw
        $html | Should -Not -Match '<script>alert\(1\)</script>'
        $html | Should -Match '&lt;script&gt;alert\(1\)&lt;/script&gt;'
    }
}
