// Parameters are non-deterministic
@description('This param is to give a unique identifier for the environment you are creating.')
@maxLength(9)
param environmentAliasPrefix string = 'nwDataOps'

@description('This param chooses which environment to deploy to, then also uses this in the name of the resource(s) to easily identify different environments in the same subscription.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentType string = 'dev'

@description('This param lets you choose which region (of the specified paired region) you be yor primary region.')
@allowed([
  'Australia East'
  'Australia SouthEast'
])
param primaryRegion string = 'Australia East'

@description('This param is the name of the SQL Server Sysadmin SQL Login.')
param sqlAdminUsername string = 'mySqlAdminUsername' // needs to be updated

@description('This param is the password for the SQL Server Sysadmin SQL Login.')
@secure()
param sqlAdminPassword string = newGuid()

@description('The ObjectId of your AzDO DataOps project Service Principal/Service Connection. You will need to update this to the ObjectId of your AzDO Projects Service Principal.')
@secure()
param azdoSpId string

// // ideally you should be using uniqueifiers as part of your resource names. this block shows how you could do that:
// var uniqueifer = take(uniqueString(subscription().id,environmentAliasPrefix,environmentType),8)
// var RgName = '${project}-rg-${uniqueifer}'
// var strgAcctName = 'strg-${uniqueifer}'

// // you could also use a tags object, instead of manually creating tags on every object
// var tagsObject = {
//   project: environmentAliasPrefix
//   environment: environmentType
// }

// for a different way to do configuration persistence, check out https://github.com/axgonz/fta-network-devops-core

// Variables are deterministic
// These variables are standard and shared across all bicep templates
var project = 'DataOps'
var environmentPrefix = toLower(environmentAliasPrefix)
// it is assumed the resource groups have already been deployed, and are in the 'primary region' 
var hubResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-hub'
var spokeResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-spoke1'

// it is assumed the resource group has already been deployed, and it is in the 'primary region'... 
var primaryRegionName = primaryRegion == 'Australia East' ? 'australiaeast' : 'australiasoutheast'
var primaryRegionSuffix = primaryRegion == 'Australia East' ? 'aue' : 'ause'
var secondaryRegion = primaryRegion == 'Australia East' ? 'Australia SouthEast' : 'Australia East'
var secondaryRegionName = secondaryRegion == 'Australia East' ? 'australiaeast' : 'australiasoutheast'
var secondaryRegionSuffix = secondaryRegion == 'Australia East' ? 'aue' : 'ause'

// These variables are specific to this bicep template
// TODO update these SIDs with the ones from your own resource groups
var devSqlAdminGroupSid = '0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a'
var testSqlAdminGroupSid = '0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a'
var prodSqlAdminGroupSid = '0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a'
var sqlAdminGroupSID = environmentType == 'dev' ? devSqlAdminGroupSid : (environmentType == 'test' ? testSqlAdminGroupSid : prodSqlAdminGroupSid)
var sqlAdminGroupName = '${environmentPrefix}-sqladmins-${environmentType}'
var ADFName = '${environmentPrefix}-adf-${environmentType}'
var ADLSg2LandingAcctName = '${environmentPrefix}adlsraw${environmentType}' // Consider adding uniquifier to this string
var ADLSg2ProcessedAcctName = '${environmentPrefix}adlsprs${environmentType}' // Consider adding uniquifier to this string
var storageAcctName = '${environmentPrefix}storage${environmentType}' // Consider adding uniquifier to this string
var keyVaultName = '${environmentPrefix}-kv-${environmentType}'
var sqlBaseServerName = '${environmentPrefix}-sqldb-${environmentType}' // Consider adding uniquifier to this string
var sqlFogName = '${environmentPrefix}fog' // Consider adding uniquifier to this string
var sharedLawsName = '${environmentAliasPrefix}-sharedlaws-${environmentType}'
var storageBlobDataContributorId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // (Get-AzRoleDefinition -Name 'Storage Blob Data Contributor').Id
var ADFMetadataDbName = 'ADFMetadataDb'

// fill in your own Git/AzDO project config #here
var devADFGitConfig = {
  type: '#type'
  accountName: '#accountname'
  projectName: '#projectName'
  repositoryName: '#repositoryName'
  collaborationBranch: 'main'
  rootFolder: 'DataFactory'
  tenantId: subscription().tenantId
}
var ADFPropertiesObject = {
  globalParameters: {
    gP_EnvironmentName: {
      type: 'string'
      value: environmentType
    }
  }
  repoConfiguration: (environmentType == 'dev' ? devADFGitConfig : null)
}

// existing resources
resource hubRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubResourcesRgName
  scope: subscription()
}

resource spokeRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: spokeResourcesRgName
  scope: subscription()
}

resource sharedLAWS 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: sharedLawsName
  scope: resourceGroup(hubResourcesRgName)
}

// new resources
resource DataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: ADFName
  location: primaryRegionName
  tags: {
    displayName: ADFName
    environment: environmentType
    project: project
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: ADFPropertiesObject
}

// ADF Diagnostic settings to support the ADFAnalyticsSolution deployed as part of the Hub IAC template
resource ADFDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${DataFactory.name}-ADFDiagSettings'
  scope: DataFactory
  properties: {
    workspaceId: sharedLAWS.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

resource KeyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: '${keyVaultName}-${primaryRegionSuffix}'
  location: primaryRegionName
  tags: {
    displayName: keyVaultName
    environment: environmentType
    project: project
  }
  properties: {
    tenantId: subscription().tenantId
    accessPolicies: []
    enabledForDiskEncryption: true
    enabledForDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enabledForTemplateDeployment: true
    sku: {
      family: 'A'
      name: 'standard'
    }
  }

 resource Kv_AccessPolicies 'accessPolicies@2019-09-01' = {
    name: 'add'
    properties: {
      accessPolicies:  [
        {
          tenantId: subscription().tenantId
          objectId: DataFactory.identity.principalId
          permissions: {
            secrets: [
              'get'
              'list'
            ]
          }
        }
        {
          tenantId: subscription().tenantId
          objectId: azdoSpId
          permissions: {
            secrets: [
              'get'
              'list'
            ]
          }
        }
      ]
    }
  }

  // This secret will be accessed by the AzDO Pipeline when compiling the template for deployment in the new NPM deployment methodology
  resource DataFactory_ResourceId 'secrets@2019-09-01' = {
    name: '${DataFactory.name}-resourceid'
    properties: {
      value: DataFactory.id
      contentType: 'ResourceId'
    }
  }
}

// Key Vault Diagnostic settings to support the Key Vault Analytics Solution deployed as part of the Hub IAC template
resource KVDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${KeyVault.name}-KVDiagSettings'
  scope: KeyVault
  properties: {
    workspaceId: sharedLAWS.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: null
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

// As of 18-July-22 Immutable storage support for accounts with a hierarchical namespace is in preview. To enroll in the preview, see this form.
// https://docs.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview#hierarchical-namespace-support
// You can however enable immutable policies at the container level for HNS enabled accounts - https://docs.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview#supported-account-configurations, though this is not covered in these templates.
module ADLSg2Account_Landing './modules/storageacct.bicep' = {
  name: ADLSg2LandingAcctName
  params: {
    accountName: '${ADLSg2LandingAcctName}${primaryRegionSuffix}'
    accountRoleAssignments: [
      {
        principalId: DataFactory.identity.principalId
        roleDefinitionId: storageBlobDataContributorId
      }
    ]
    location: primaryRegionName
    environmentType: environmentType
    project: project
    makeRAGRS: true
    isDataLake: true
    isLakeLanding: true
    enableSoftDelete: true
    enableSftp: false
    containersWithRoleAssignments: [
      {
        containerName: 'raw'
        makeImmutable: false
        permissions: [
          {
            principalId: DataFactory.identity.principalId
            roleDefinitionId: storageBlobDataContributorId
          }
        ]
      }
      {
        containerName: 'processed'
        makeImmutable: false
        permissions: [
          {
            principalId: DataFactory.identity.principalId
            roleDefinitionId: storageBlobDataContributorId
          }
        ]
      }
      {
        containerName: 'malformed'
        makeImmutable: false
        permissions: [
          {
            principalId: DataFactory.identity.principalId
            roleDefinitionId: storageBlobDataContributorId
          }
        ]
      }
    ]
  }
}

module ADLSg2Account_Processed './modules/storageacct.bicep' = {
  name: ADLSg2ProcessedAcctName
  params: {
    accountName: '${ADLSg2ProcessedAcctName}${primaryRegionSuffix}'
    accountRoleAssignments: [
      {
        principalId: DataFactory.identity.principalId
        roleDefinitionId: storageBlobDataContributorId
      }
    ]
    location: primaryRegionName
    environmentType: environmentType
    project: project
    makeRAGRS: false
    isDataLake: true
    isLakeLanding: false
    enableSoftDelete: false
    enableSftp: false
    containersWithRoleAssignments: [
      // container to hold the first cut of files / base processed files / bronze zone of the lake
      {
        containerName: 'landing'
        makeImmutable: false
        permissions: [
          {
            principalId: DataFactory.identity.principalId
            roleDefinitionId: storageBlobDataContributorId
          }
        ]
      }
      // container for the conformed / silver zone of the lake
      {
        containerName: 'conformed'
        makeImmutable: false
        permissions: [
          {
            principalId: DataFactory.identity.principalId
            roleDefinitionId: storageBlobDataContributorId
          }
        ]
      }
      // container for the curated / presentation / gold zone of the lake
      {
        containerName: 'curated'
        makeImmutable: false
        permissions: [
          {
            principalId: DataFactory.identity.principalId
            roleDefinitionId: storageBlobDataContributorId
          }
        ]
      }
    ]
  }
}

module StorageAccount './modules/storageacct.bicep' = {
  name: storageAcctName
  params: {
    accountName: '${storageAcctName}${primaryRegionSuffix}'
    accountRoleAssignments: [
      {
        principalId: DataFactory.identity.principalId
        roleDefinitionId: storageBlobDataContributorId
      }
    ]
    location: primaryRegionName
    environmentType: environmentType
    project: project
    makeRAGRS: true
    isDataLake: false
    enableSoftDelete: true
    enableBlobChangeFeed: false
    enableBlobVersioning: false
    containersWithRoleAssignments: [
      // container to hold the PowerBI Financial Sample.xlsx file - https://docs.microsoft.com/en-us/power-bi/create-reports/sample-financial-download
      {
        containerName: 'source'
        makeImmutable: false
        permissions: [
          {
            principalId: DataFactory.identity.principalId
            roleDefinitionId: storageBlobDataContributorId
          }
        ]
      }
      // container to hold sql vulnerability assessment results. MUST BE CALLED 'vulnerability-assessment'
      {
        containerName: 'vulnerability-assessment'
        makeImmutable: false
        permissions: []
      }
      // output for adf metadata driven transformations
      {
        containerName: 'adflogs'
        makeImmutable: false
        permissions: []
      }
      // staging location for adf metadata driven transformations
      {
        containerName: 'adfstaging'
        makeImmutable: false
        permissions: []
      }
    ]
  }
}

// module PrimaryAzureSQLDB_Server './modules/sqlserver.bicep' = if (deploySql == true) { // you can do conditional deployments of a resource like this
module PrimaryAzureSQLDB_Server './modules/sqlserver.bicep' = {
  name: '${sqlBaseServerName}-${primaryRegionSuffix}'
  params: {
    sqlServerName: '${sqlBaseServerName}-${primaryRegionSuffix}'
    location: primaryRegionName
    environmentType: environmentType
    sqlAdminGroupName: sqlAdminGroupName
    sqlAdminGroupSID: sqlAdminGroupSID
    sqlAdminUsername: sqlAdminUsername
    // sqlAdminPassword: sqlAdminPassword // this is commented out so each server will have a different admin password dynamically generated at runtime
    project: project
    vulnerabilityAssessmentStorageAcctName: StorageAccount.outputs.AccountName
    keyVaultName: KeyVault.name
    configAllowAzureIpsFwRule: true
    configAdventureWorksDb: true
  }
}

module SecondaryAzureSQLDB_Server './modules/sqlserver.bicep' = {
  name: '${sqlBaseServerName}-${secondaryRegionSuffix}'
  params: {
    sqlServerName: '${sqlBaseServerName}-${secondaryRegionSuffix}'
    location: secondaryRegionName
    environmentType: environmentType
    sqlAdminGroupName: sqlAdminGroupName
    sqlAdminGroupSID: sqlAdminGroupSID
    sqlAdminUsername: sqlAdminUsername
    // sqlAdminPassword: sqlAdminPassword // this is commented out so each server will have a different admin password dynamically generated at runtime
    project: project
    vulnerabilityAssessmentStorageAcctName: StorageAccount.outputs.AccountName
    keyVaultName: KeyVault.name
    configAllowAzureIpsFwRule: true
    configAdventureWorksDb: false
  }
}

module FOG1SeedDb './modules/sqldb.bicep' = {
  name: 'fog1seeddb'
  params: {
    sqlServerName: PrimaryAzureSQLDB_Server.name
    dbName: 'fog1seeddb'
    location: primaryRegion
    environment: environmentType
    project: project
    lawsId: sharedLAWS.id
    keyVaultName: KeyVault.name
    saveDbConnStr: false
  }
}

module ADFMetadataDb './modules/sqldb.bicep' = {
  name: ADFMetadataDbName
  params: {
    sqlServerName: PrimaryAzureSQLDB_Server.name
    dbName: ADFMetadataDbName
    location: primaryRegion
    environment: environmentType
    project: project
    lawsId: sharedLAWS.id
    keyVaultName: KeyVault.name
    saveDbConnStr: true
  }
}

module SimpleSamplesDb './modules/sqldb.bicep' = {
  name: 'SimpleSamples'
  params: {
    sqlServerName: PrimaryAzureSQLDB_Server.name
    dbName: 'SimpleSamples'
    location: primaryRegion
    environment: environmentType
    project: project
    lawsId: sharedLAWS.id
    keyVaultName: KeyVault.name
    saveDbConnStr: true
  }
}

module SqlFOG './modules/sqlfog.bicep' = {
  name: 'SqlFailoverGroup'
  params: {
    sqlFogName: '${sqlFogName}-${environmentType}-1'
    primarySqlServerName: PrimaryAzureSQLDB_Server.name
    secondarySqlServerName: SecondaryAzureSQLDB_Server.name
    databasesArray: [
      FOG1SeedDb.outputs.dbId
      ADFMetadataDb.outputs.dbId
      SimpleSamplesDb.outputs.dbId
    ]
    keyVaultName: KeyVault.name
    saveFogConnStr: true
  }
}

resource ADFMetadataDb_FOG_ConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: '${ADFMetadataDb.name}-FOG-ConnectionString'
  parent: KeyVault
  properties: {
    value: 'Server=tcp:${SqlFOG.outputs.SqlFogName}${az.environment().suffixes.sqlServerHostname},1433;Initial Catalog=${ADFMetadataDbName};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Integrated Security=False;'
    contentType: 'Connection String'
  }
}
