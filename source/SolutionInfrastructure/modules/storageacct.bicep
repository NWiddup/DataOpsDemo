param accountName string
param accountRoleAssignments array = [
  {
    principalId: ''
    roleDefinitionId: ''
  }
]
param location string
param environmentType string
param project string
param makeRAGRS bool = false
param isDataLake bool = false
param isLakeLanding bool = false
param enableSftp bool = false
param enableSoftDelete bool = false
param enableBlobVersioning bool = false
param enableBlobChangeFeed bool = false
// param enableImmutableBlobStorage bool = false
param containersWithRoleAssignments array = [
  {
    containerName: ''
    makeImmutable: false
    permissions: [
      {
        principalId: ''
        roleDefinitionId: ''
      }
    ]
  }
]

var sku = makeRAGRS == true || isLakeLanding == true ? 'Standard_RAGRS' : location == 'aue' ? 'Standard_ZRS' : 'Standard_LRS'
var retentionDays = 30

var storagePolicyDisabled = {
  enabled: false
}

var retentionPoliciesObjectDisabled = storagePolicyDisabled
var retentionPoliciesObjectEnabled = {
  enabled: true
  days: retentionDays
}
var retentionPolicy = isLakeLanding == true || enableSoftDelete == true ? retentionPoliciesObjectEnabled : retentionPoliciesObjectDisabled

// var immutableStorageObjectDisabled = storagePolicyDisabled
// var immutableStorageObjectEnabled = {
//   enabled: true
//   immutabilityPolicy: {
//     allowProtectedAppendWrites: true
//     immutabilityPeriodSinceCreationInDays: retentionDays
//   }
// }
// var versionLevelWormEnabled = enableImmutableBlobStorage == true ? immutableStorageObjectEnabled : immutableStorageObjectDisabled

resource StorageAcct 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: accountName
  location: location
  tags: {
    displayName: accountName
    environment: environmentType
    project: project
  }
  kind: 'StorageV2'
  sku: {
    name: sku
  }
  properties: {
    isHnsEnabled: isDataLake
    // immutableStorageWithVersioning: versionLevelWormEnabled
    isSftpEnabled: (isDataLake == true && enableSftp == true ? true : false) // only supported with HNS enabled
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource BlobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  name: 'default'
  parent: StorageAcct
  properties: {
    isVersioningEnabled: (isDataLake == false && enableBlobVersioning == true ? true : false) // not supported with HNS enabled
    deleteRetentionPolicy: retentionPolicy
    containerDeleteRetentionPolicy: retentionPolicy
    changeFeed: {
      enabled: (isDataLake == false && enableBlobChangeFeed == true ? true : false) // not supported with HNS enabled
    }
  }
}

resource StorageAccountRoleAssignments 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for i in range(0, length(accountRoleAssignments)): {
  name: guid(StorageAcct.name, subscription().id, accountRoleAssignments[i].principalId)
  scope: StorageAcct
  properties: {
    principalId: accountRoleAssignments[i].principalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${accountRoleAssignments[i].roleDefinitionId}'
  }
}]

module Containers './storagecontainer.bicep' = [for container in containersWithRoleAssignments: {
  name: '${container.containerName}_Container'
  dependsOn: [
    BlobService
  ]
  params: {
    storageAccountName: StorageAcct.name
    containerName: container.containerName
    permissionsArray: container.permissions
    isLakeLanding: isLakeLanding
    makeImmutable: container.makeImmutable
  }
}]

output AccountName string = StorageAcct.name
