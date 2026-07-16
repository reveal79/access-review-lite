BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../AccessReviewLite.psd1'
    Import-Module $modulePath -Force
}

Describe 'Graph collection failure classification' {
    It 'classifies authorization failures separately' {
        InModuleScope AccessReviewLite {
            try { throw 'Authorization_RequestDenied: Insufficient privileges' } catch { $failure = Get-CollectionFailure -ErrorRecord $_ }
            $failure.ReasonCode | Should -Be 'PermissionDenied'
        }
    }

    It 'classifies licensing failures separately' {
        InModuleScope AccessReviewLite {
            try { throw 'The tenant license does not include this report' } catch { $failure = Get-CollectionFailure -ErrorRecord $_ }
            $failure.ReasonCode | Should -Be 'LicenseUnavailable'
        }
    }

    It 'returns an unavailable dataset instead of terminating collection' {
        InModuleScope AccessReviewLite {
            $result = Invoke-OptionalGraphDataset -Name 'Optional data' -Collector { throw 'Forbidden' }
            $result.Metadata.Status | Should -Be 'Unavailable'
            $result.Metadata.ReasonCode | Should -Be 'PermissionDenied'
            @($result.Records).Count | Should -Be 0
        }
    }
}
