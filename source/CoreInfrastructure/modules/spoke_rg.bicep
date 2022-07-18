param environmentAliasPrefix string = 'nwDataOps'

@allowed([
  'dev'
  'test'
  'prod'
])
param environmentType string = 'dev'

@allowed([
  'Australia East'
  'Australia SouthEast'
])
param primaryRegion string = 'Australia East'
param azdoSpId string // (az ad sp show --id $sp.appId).objectId

var primaryRegionName = primaryRegion == 'Australia East' ? 'australiaeast' : 'australiasoutheast'
var hubResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-hub'
var spokeResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-spoke1'
var rgContributorId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // (Get-AzRoleDefinition -Name Contributor).Id

resource AzureDevOpsPipeline_RGContributorPermission 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(spokeResourcesRgName, subscription().id, azdoSpId)
  properties: {
    principalId: azdoSpId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${rgContributorId}'
  }
}
