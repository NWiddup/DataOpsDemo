param sqlServerName string
param location string
param environmentType string
param sqlAdminGroupName string
param sqlAdminGroupSID string
param sqlAdminUsername string
@secure()
param sqlAdminPassword string = newGuid()
param project string
param vulnerabilityAssessmentStorageAcctName string = ''
param keyVaultName string = ''
// all config* properties are binary flags
param configAADAuthOnly bool = false
param configAllowAzureIpsFwRule bool = false
param configAdventureWorksDb bool = false
param configEnableAuditing bool = true
// param configEnableATP bool = false // uncomment the ATP config if you have ATP enabled for the sub & want it on this server

// existing resources
resource KeyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = if (keyVaultName != '') {
  name: keyVaultName
}

// new resources
resource SQLServer 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: sqlServerName
  location: location
  tags: {
    displayName: sqlServerName
    environment: environmentType
    project: project
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    minimalTlsVersion: '1.2'
    version: '12.0'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword

  }

  resource AADAdmin 'administrators@2021-11-01-preview' = if (sqlAdminGroupName != '' && sqlAdminGroupSID != '') {
    name: 'ActiveDirectory'
    properties: {
      tenantId: subscription().tenantId
      administratorType: 'ActiveDirectory'
      login: sqlAdminGroupName
      sid: sqlAdminGroupSID
    }
  }

  resource AADAuthOnly 'azureADOnlyAuthentications@2020-02-02-preview' = {
    name: 'Default'
    dependsOn: [
      AADAdmin
    ]
    properties: {
      azureADOnlyAuthentication: configAADAuthOnly
    }
  }

  resource Firewall 'firewallRules@2021-11-01-preview' = if (configAllowAzureIpsFwRule == true) {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  resource EncryptionProtector 'encryptionProtector@2021-11-01-preview' = {
    name: 'current'
    properties: {
      serverKeyName: 'ServiceManaged'
      serverKeyType: 'ServiceManaged'
      autoRotationEnabled: true
    }
  }

  // this is 'Azure SQL Auditing' -> creates DiagnosticSettings in the Master DB for 'SQLSecurityAuditEvents'
  resource auditingSettings 'auditingSettings@2021-11-01-preview' = if (configEnableAuditing == true) {
    name: 'default'
    properties: {
      state: 'Enabled'
      isAzureMonitorTargetEnabled: true
      isDevopsAuditEnabled: true
      auditActionsAndGroups: [
        'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
        'FAILED_DATABASE_AUTHENTICATION_GROUP'
        'BATCH_COMPLETED_GROUP'
        'DATABASE_LOGOUT_GROUP' //manually added so we can trach which accounts are using which databases, and how much
        'DBCC_GROUP' //manually added just in case people do weird things with DBCC
      ]
    }
  }
  
  // this is 'Auditing of Microsoft support operations' -> creates DiagnosticSettings in the Master DB for 'DevOpsOperationsAudit'
  resource devOpsAuditingSettings 'devOpsAuditingSettings@2021-11-01-preview' = if (configEnableAuditing == true) {
    name: 'default'
    properties: {
      state: 'Enabled'
      isAzureMonitorTargetEnabled: true
    }
  }

  resource IdentifyingDb 'databases@2020-08-01-preview' = {
    name: 'aaServerName-${sqlServerName}'
    location: location
    tags: {
      displayName: sqlServerName
      environment: environmentType
    }
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
      zoneRedundant: false
      readScale: 'Disabled'
      createMode: 'Default'
    }
  }

  resource AdventureWorksLTDb 'databases@2020-08-01-preview' = if (configAdventureWorksDb == true) {
    name: 'AdventureWorksLT'
    location: location
    tags: {
      displayName: sqlServerName
      environment: environmentType
    }
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
      zoneRedundant: false
      readScale: 'Disabled'
      sampleName: 'AdventureWorksLT'
    }
  }

  // resource SqlServer_ATP 'advancedThreatProtectionSettings@2021-11-01-preview' = if (configEnableATP == true) {
  //   name: 'Default'
  //   properties: {
  //     state: 'Enabled'
  //   }
  // }
}

// SQL VA depends on ATP being enabled on the SQL Server. If you have configured ATP/VA at the subscription level, the first time you publish this template, VA will fail as ATP has not yet fully provisioned. Alternatively, if you only enable ATP on a server-by-server basis, then set the relevant parameters at runtime.
resource SqlServer_VulnerabilityAssessments 'Microsoft.Sql/servers/vulnerabilityAssessments@2021-11-01-preview' = if (vulnerabilityAssessmentStorageAcctName != '') {
  name: 'default'
  parent: SQLServer
  properties: {
    storageContainerPath: 'https://${vulnerabilityAssessmentStorageAcctName}.blob.${az.environment().suffixes.storage}/vulnerability-assessment'
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: false
    }
  }
}

resource SQLServer_SAPWSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = if (KeyVault.id != '') {
  name: '${SQLServer.name}-sqlAdminPassword'
  parent: KeyVault
  properties: {
    value: sqlAdminPassword
    contentType: 'Password'
  }
}

output sqlServerObj object = SQLServer
output sqlServerId string = SQLServer.id
output sqlServerAdventureworksDbId string = configAdventureWorksDb == true ? SQLServer::AdventureWorksLTDb.id : ''
