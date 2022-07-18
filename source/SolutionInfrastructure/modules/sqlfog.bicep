param sqlFogName string
param primarySqlServerName string 
param secondarySqlServerName string
param databasesArray array
param keyVaultName string = ''
param saveFogConnStr bool = true
param enableReadOnlyEndpoint bool = true

// existing resources
resource KeyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = if (keyVaultName != '') {
  name: keyVaultName
}

resource PrimarySqlServer 'Microsoft.Sql/servers@2021-11-01-preview' existing = {
  name: primarySqlServerName
}

resource SecondarySqlServer 'Microsoft.Sql/servers@2021-11-01-preview' existing = {
  name: secondarySqlServerName
}

// new resources
resource SqlFOG 'Microsoft.Sql/servers/failoverGroups@2015-05-01-preview' = {
  name: sqlFogName
  parent: PrimarySqlServer
  properties: {
    readWriteEndpoint: {
      failoverPolicy: 'Automatic'
      failoverWithDataLossGracePeriodMinutes: 60
    }
    readOnlyEndpoint: {
      failoverPolicy: (enableReadOnlyEndpoint == true ? 'Enabled' : 'Disabled')
    }
    partnerServers: [
      {
        id: SecondarySqlServer.id
      }
    ]
    databases: databasesArray
  }
}

resource SQLFOG_ConnStr_KVSecret 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = if (saveFogConnStr == true && keyVaultName != '') {
  name: '${sqlFogName}-ConnectionString'
  parent: KeyVault
  properties: {
    value: 'Server=tcp:${SqlFOG.properties.readWriteEndpoint}${az.environment().suffixes.sqlServerHostname},1433;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Integrated Security=False;'
    contentType: 'Connection String'
  }
}

output SqlFogName string = string(SqlFOG.name)
