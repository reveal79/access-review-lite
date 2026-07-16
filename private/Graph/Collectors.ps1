function Get-PropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()][object] $InputObject,
        [Parameter(Mandatory)][string] $Name
    )
    if ($null -eq $InputObject) { return $null }
    if ($InputObject.PSObject.Properties.Name -contains $Name) { return $InputObject.$Name }
    return $null
}

function Get-LiveAccessReviewRawData {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object] $GraphContext)

    $metadata = [System.Collections.Generic.List[object]]::new()

    $usersResult = Invoke-OptionalGraphDataset -Name 'Directory users' -Collector {
        Invoke-GraphPagedRequest -Uri 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,userType,accountEnabled,createdDateTime'
    }
    $metadata.Add($usersResult.Metadata)
    $users = @($usersResult.Records)
    $userById = @{}
    foreach ($user in $users) { $userById[[string]$user.id] = $user }

    $activityResult = Invoke-OptionalGraphDataset -Name 'Sign-in activity' -Collector {
        Invoke-GraphPagedRequest -Uri 'https://graph.microsoft.com/v1.0/users?$select=id,signInActivity'
    }
    $metadata.Add($activityResult.Metadata)
    $activityById = @{}
    foreach ($record in $activityResult.Records) { $activityById[[string]$record.id] = $record.signInActivity }

    $mfaResult = Invoke-OptionalGraphDataset -Name 'MFA registration' -Collector {
        Invoke-GraphPagedRequest -Uri 'https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails'
    }
    $metadata.Add($mfaResult.Metadata)
    $mfaById = @{}
    foreach ($record in $mfaResult.Records) { $mfaById[[string]$record.id] = $record }

    $roleDefinitionsResult = Invoke-OptionalGraphDataset -Name 'Directory role definitions' -Collector {
        Invoke-GraphPagedRequest -Uri 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?$select=id,displayName,isBuiltIn'
    }
    $metadata.Add($roleDefinitionsResult.Metadata)
    $roleDefinitions = @{}
    foreach ($definition in $roleDefinitionsResult.Records) { $roleDefinitions[[string]$definition.id] = [string]$definition.displayName }

    $roleAssignmentsResult = Invoke-OptionalGraphDataset -Name 'Directory role assignments' -Collector {
        Invoke-GraphPagedRequest -Uri 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?$expand=principal&$select=id,principalId,roleDefinitionId,directoryScopeId'
    }
    $metadata.Add($roleAssignmentsResult.Metadata)

    $rolesByUserId = @{}
    $nonUserById = @{}
    foreach ($assignment in $roleAssignmentsResult.Records) {
        $principalId = [string]$assignment.principalId
        $roleName = if ($roleDefinitions.ContainsKey([string]$assignment.roleDefinitionId)) { $roleDefinitions[[string]$assignment.roleDefinitionId] } else { [string]$assignment.roleDefinitionId }
        $principal = Get-PropertyValue -InputObject $assignment -Name 'principal'
        $odataType = [string](Get-PropertyValue -InputObject $principal -Name '@odata.type')
        $isUser = $userById.ContainsKey($principalId) -or $odataType -eq '#microsoft.graph.user'
        if ($isUser) {
            if (-not $rolesByUserId.ContainsKey($principalId)) { $rolesByUserId[$principalId] = [System.Collections.Generic.List[string]]::new() }
            $rolesByUserId[$principalId].Add($roleName)
        }
        else {
            if (-not $nonUserById.ContainsKey($principalId)) {
                $typeName = if ($odataType) { $odataType -replace '^#microsoft.graph\.', '' } else { 'Unknown' }
                $nonUserById[$principalId] = [pscustomobject]@{
                    Id            = $principalId
                    DisplayName   = if ($principal.displayName) { [string]$principal.displayName } else { $principalId }
                    PrincipalType = $typeName
                    Roles         = [System.Collections.Generic.List[string]]::new()
                }
            }
            $nonUserById[$principalId].Roles.Add($roleName)
        }
    }

    $servicePrincipalsResult = Invoke-OptionalGraphDataset -Name 'Service principals' -Collector {
        Invoke-GraphPagedRequest -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals?$select=id,appId,displayName,servicePrincipalType,appRoles,oauth2PermissionScopes'
    }
    $metadata.Add($servicePrincipalsResult.Metadata)
    $servicePrincipalById = @{}
    foreach ($servicePrincipal in $servicePrincipalsResult.Records) { $servicePrincipalById[[string]$servicePrincipal.id] = $servicePrincipal }

    $appRoleGrants = [System.Collections.Generic.List[object]]::new()
    $appRoleFailures = [System.Collections.Generic.List[string]]::new()
    foreach ($client in $servicePrincipalsResult.Records) {
        try {
            $assignments = Invoke-GraphPagedRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($client.id)/appRoleAssignments"
            foreach ($assignment in $assignments) {
                $resource = if ($servicePrincipalById.ContainsKey([string]$assignment.resourceId)) { $servicePrincipalById[[string]$assignment.resourceId] } else { $null }
                $definition = @($resource.appRoles | Where-Object { [string]$_.id -eq [string]$assignment.appRoleId } | Select-Object -First 1)
                $permissionName = if ($definition.Count -gt 0 -and $definition[0].value) { [string]$definition[0].value } else { [string]$assignment.appRoleId }
                $appRoleGrants.Add([pscustomobject]@{
                    Id                  = [string]$assignment.id
                    ClientId            = [string]$client.id
                    ClientDisplayName   = [string]$client.displayName
                    ResourceId          = [string]$assignment.resourceId
                    ResourceDisplayName = if ($resource) { [string]$resource.displayName } else { [string]$assignment.resourceDisplayName }
                    Permission          = $permissionName
                    GrantType           = 'Application'
                    ConsentType         = 'Application'
                })
            }
        }
        catch {
            $appRoleFailures.Add("$($client.displayName): $($_.Exception.Message)")
        }
    }
    if ($servicePrincipalsResult.Metadata.Status -eq 'Unavailable') {
        $metadata.Add((Get-CollectionMetadataRecord -Name 'Application permissions' -Status Unavailable -ReasonCode $servicePrincipalsResult.Metadata.ReasonCode -Reason 'Service-principal inventory was unavailable, so application permissions could not be collected.'))
    }
    elseif ($appRoleFailures.Count -gt 0) {
        $metadata.Add((Get-CollectionMetadataRecord -Name 'Application permissions' -Status Partial -ReasonCode 'CollectionError' -Reason ($appRoleFailures -join ' | ') -RecordCount $appRoleGrants.Count))
    }
    else {
        $metadata.Add((Get-CollectionMetadataRecord -Name 'Application permissions' -Status Available -RecordCount $appRoleGrants.Count))
    }

    $delegatedResult = Invoke-OptionalGraphDataset -Name 'Delegated OAuth grants' -Collector {
        Invoke-GraphPagedRequest -Uri 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants'
    }
    $metadata.Add($delegatedResult.Metadata)
    $delegatedGrants = [System.Collections.Generic.List[object]]::new()
    foreach ($grant in $delegatedResult.Records) {
        $client = if ($servicePrincipalById.ContainsKey([string]$grant.clientId)) { $servicePrincipalById[[string]$grant.clientId] } else { $null }
        $resource = if ($servicePrincipalById.ContainsKey([string]$grant.resourceId)) { $servicePrincipalById[[string]$grant.resourceId] } else { $null }
        foreach ($scope in @(([string]$grant.scope -split '\s+') | Where-Object { $_ })) {
            $delegatedGrants.Add([pscustomobject]@{
                Id                  = "$($grant.id):$scope"
                ClientId            = [string]$grant.clientId
                ClientDisplayName   = if ($client) { [string]$client.displayName } else { [string]$grant.clientId }
                ResourceId          = [string]$grant.resourceId
                ResourceDisplayName = if ($resource) { [string]$resource.displayName } else { [string]$grant.resourceId }
                Permission          = $scope
                GrantType           = 'Delegated'
                ConsentType         = [string]$grant.consentType
            })
        }
    }

    function ConvertTo-RawUserRecord {
        param([object] $User, [string[]] $Roles)
        $id = [string]$User.id
        $activity = if ($activityById.ContainsKey($id)) { $activityById[$id] } else { $null }
        $lastSuccessful = Get-PropertyValue -InputObject $activity -Name 'lastSuccessfulSignInDateTime'
        if (-not $lastSuccessful) { $lastSuccessful = Get-PropertyValue -InputObject $activity -Name 'lastSignInDateTime' }
        $activityReasonCode = if ($activityResult.Metadata.Status -eq 'Unavailable') { $activityResult.Metadata.ReasonCode } else { $null }
        $activityReason = if ($activityResult.Metadata.Status -eq 'Unavailable') { $activityResult.Metadata.Reason } elseif (-not $lastSuccessful) { 'No conclusive successful sign-in timestamp was returned.' } else { $null }

        $mfa = if ($mfaById.ContainsKey($id)) { $mfaById[$id] } else { $null }
        $mfaState = if ($mfaResult.Metadata.Status -eq 'Unavailable') {
            if ($mfaResult.Metadata.ReasonCode -eq 'PermissionDenied') { 'UnavailablePermissions' }
            elseif ($mfaResult.Metadata.ReasonCode -eq 'LicenseUnavailable') { 'UnavailableLicensing' }
            else { 'Unknown' }
        }
        elseif ($mfa) {
            if ([bool]$mfa.isMfaRegistered) { 'Registered' } else { 'NotRegistered' }
        }
        else { 'Unknown' }

        [pscustomobject]@{
            Id                = $id
            DisplayName       = [string]$User.displayName
            UserPrincipalName = [string]$User.userPrincipalName
            AccountEnabled    = $User.accountEnabled
            CreatedDateTime   = [string]$User.createdDateTime
            Roles             = @($Roles)
            Activity          = [pscustomobject]@{
                LastSignInDateTime    = $lastSuccessful
                NeverSignedIn         = $false
                UnavailableReasonCode = $activityReasonCode
                Reason                = $activityReason
            }
            Mfa               = [pscustomobject]@{
                State  = $mfaState
                Reason = if ($mfaResult.Metadata.Status -eq 'Unavailable') { $mfaResult.Metadata.Reason } else { $null }
            }
        }
    }

    $privileged = @($rolesByUserId.Keys | ForEach-Object {
        if ($userById.ContainsKey($_)) { ConvertTo-RawUserRecord -User $userById[$_] -Roles @($rolesByUserId[$_]) }
    })
    $guests = @($users | Where-Object userType -eq 'Guest' | ForEach-Object { ConvertTo-RawUserRecord -User $_ -Roles @() })

    $tenantName = if ($GraphContext.PSObject.Properties.Name -contains 'Account') { "Tenant for $($GraphContext.Account)" } else { 'Microsoft Entra tenant' }
    return [pscustomobject]@{
        Tenant = [pscustomobject]@{ Id = [string]$GraphContext.TenantId; DisplayName = $tenantName; Mode = 'Live' }
        CollectionMetadata = @($metadata)
        PrivilegedAccounts = $privileged
        NonUserPrivilegedPrincipals = @($nonUserById.Values)
        Guests = $guests
        PermissionGrants = @($appRoleGrants) + @($delegatedGrants)
    }
}
