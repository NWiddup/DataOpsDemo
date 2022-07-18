param storageAccountName string
param containerName string
param permissionsArray array = [
  {
    principalId: ''
    roleDefinitionId: ''
  }
]
param isLakeLanding bool = false // to be added in future
param makeImmutable bool = false


// existing resources
resource StorageAcct 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

resource BlobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' existing = {
  name: 'default'
  parent: StorageAcct
}

// new resources
resource Container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: containerName
  parent: BlobService
  properties: {
    publicAccess: 'None'
    // immutableStorageWithVersioning: {
    //   enabled: false
    // }
  }
}

// immutable storage for HNS objects is still in preview. Consider adding 'isLakeLanding == true || makeImmutable == true' to the if clause below once it's enabled
// https://docs.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview#hierarchical-namespace-support
resource ImmutablePolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2021-09-01' = if (makeImmutable == true) {
  name: 'default'
  parent: Container
  properties: {
    allowProtectedAppendWrites: false
    immutabilityPeriodSinceCreationInDays: 30
  }
}

resource ContainerAccessPolicies 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for perm in permissionsArray: {
  name: guid(StorageAcct.name, subscription().id, Container.name, perm.principalId, perm.roleDefinitionId)
  scope: Container
  properties: {
    principalId: perm.principalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${perm.roleDefinitionId}'
  }
}]

output ContainerId string = Container.id
