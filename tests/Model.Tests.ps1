BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../AccessReviewLite.psd1'
    Import-Module $modulePath -Force
    $script:asOf = [DateTimeOffset]'2026-07-15T17:00:00Z'
    $script:raw = Import-AccessReviewDemoData
    $script:data = ConvertTo-AccessReviewNormalizedData -InputObject $raw -AsOf $asOf
}

Describe 'Normalized activity model' {
    It 'represents all six activity states without collapsing uncertainty' {
        $states = @($data.PrivilegedAccounts.Activity.State) + @($data.Guests.Activity.State)
        $states | Should -Contain 'confirmed_active'
        $states | Should -Contain 'confirmed_stale'
        $states | Should -Contain 'never_signed_in'
        $states | Should -Contain 'activity_unavailable_licensing'
        $states | Should -Contain 'activity_unavailable_permissions'
        $states | Should -Contain 'activity_unknown'
    }

    It 'uses the approved administrator and guest thresholds' {
        $data.Thresholds.StaleAdministratorDays | Should -Be 90
        $data.Thresholds.StaleGuestDays | Should -Be 180
    }

    It 'marks a recent administrator as confirmed active' {
        ($data.PrivilegedAccounts | Where-Object Id -eq 'admin-1').Activity.State | Should -Be 'confirmed_active'
    }

    It 'marks an old administrator sign-in as confirmed stale' {
        ($data.PrivilegedAccounts | Where-Object Id -eq 'admin-2').Activity.State | Should -Be 'confirmed_stale'
    }
}
