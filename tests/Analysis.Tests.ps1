BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../AccessReviewLite.psd1'
    Import-Module $modulePath -Force
    $raw = Import-AccessReviewDemoData
    $script:data = ConvertTo-AccessReviewNormalizedData -InputObject $raw -AsOf ([DateTimeOffset]'2026-07-15T17:00:00Z')
    $script:analysis = Get-AccessReviewAnalysis -Data $data
}

Describe 'Access review analysis rules' {
    It 'assigns approved severities to privileged-account findings' {
        ($analysis.Findings | Where-Object RuleId -eq 'ARL-ADMIN-001').Severity | Should -Be 'Critical'
        ($analysis.Findings | Where-Object RuleId -eq 'ARL-ADMIN-002').Severity | Should -Be 'Critical'
        ($analysis.Findings | Where-Object RuleId -eq 'ARL-ADMIN-003').Severity | Should -Be 'High'
    }

    It 'does not create activity or MFA findings from unavailable data' {
        @($analysis.Findings | Where-Object Subject -eq 'miriam@northwind.example').Count | Should -Be 0
    }

    It 'creates only an informational review for an old guest with unavailable activity' {
        $finding = $analysis.Findings | Where-Object Subject -eq 'unknown#EXT#@northwind.example'
        @($finding).Count | Should -Be 1
        $finding.Severity | Should -Be 'Informational'
        $finding.Evidence | Should -Match 'staleness is not asserted'
    }

    It 'does not create a finding for recent unknown activity' {
        @($analysis.Findings | Where-Object Subject -eq 'indeterminate#EXT#@northwind.example').Count | Should -Be 0
    }

    It 'uses the transparent permission catalog and ignores uncataloged read access' {
        @($analysis.Findings | Where-Object Category -eq 'Application permissions').Count | Should -Be 2
        @($analysis.Findings | Where-Object Evidence -match 'User.Read.All').Count | Should -Be 0
    }

    It 'produces deterministic demo counts' {
        $analysis.Counts.Critical | Should -Be 3
        $analysis.Counts.High | Should -Be 3
        $analysis.Counts.Medium | Should -Be 2
        $analysis.Counts.Informational | Should -Be 1
        $analysis.Counts.Total | Should -Be 9
    }
}
