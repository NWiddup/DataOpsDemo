param sqlServerName string
param dbName string
param location string
@allowed([
  'SQL_Latin1_General_CP1_CI_AS'
])
param collation string = 'SQL_Latin1_General_CP1_CI_AS'
param environment string
param project string
param sku object = {
  name: 'Standard'
  tier: 'Standard'
  capacity: 10
}
@secure()
param lawsId string = ''
param keyVaultName string = ''
param saveDbConnStr bool = false

var dbDiagSettingsName = '${dbName}-dbdiagsettings1' // use '-${substring(uniqueString(sqlServerName, dbName, laws_workspaceId),0,8)}' for uniqueness

// existing resources
resource SqlServer 'Microsoft.Sql/servers@2021-11-01-preview' existing = {
  name: sqlServerName
}

resource KeyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = if (keyVaultName != '') {
  name: keyVaultName
}

// new resources
resource Database 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  name: dbName
  parent: SqlServer
  location: location
  sku: {
    name: sku.name
    tier: sku.tier
    capacity: sku.capacity
    
  }
  tags: {
    displayName: dbName
    environment: environment
    project: project
  }
  properties: {
    collation: collation
    zoneRedundant: false
    readScale: 'Disabled'
    createMode: 'Default'
    // isLedgerOn: false
  }

}

resource Database_kvSecret_connStr 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = if (saveDbConnStr == true && keyVaultName != '') {
  name: '${Database.name}-ConnectionString'
  parent: KeyVault
  properties:{
    value: 'Server=tcp:${SqlServer.name}${az.environment().suffixes.sqlServerHostname},1433;Initial Catalog=${Database.name};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Integrated Security=False;'
    contentType: 'Connection String'
  }
}


resource Database_AuditSettings 'Microsoft.Sql/servers/databases/auditingSettings@2017-03-01-preview' = {
  name: 'default'
  parent: Database
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

resource Database_ExtendedAuditSettings 'Microsoft.Sql/servers/databases/extendedAuditingSettings@2017-03-01-preview' = {
  name: 'default'
  parent: Database
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

resource DB_DiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (lawsId != '') {
  name: dbDiagSettingsName
  scope: Database
  properties: {
    workspaceId: lawsId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {   
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'AutomaticTuning'
        enabled: true
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
      }
      {
        category: 'Errors'
        enabled: true
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
      }
      {
        category: 'Timeouts'
        enabled: true
      }
      {
        category: 'Blocks'
        enabled: true
      }
      {
        category: 'Deadlocks'
        enabled: true
      }
      {
        category: 'DevOpsOperationsAudit'
        enabled: true
      }
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
      }
      {
        category: 'InstanceAndAppAdvanced'
        enabled: true
      }
      {
        category: 'WorkloadManagement'
        enabled: true
      }
    ]
  }
}

output dbId string = Database.id
output dbName string = Database.name

// consider adding audit definitions and other security config (such as TDE config) to your environment build script
