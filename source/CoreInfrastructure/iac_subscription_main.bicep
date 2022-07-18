// https://github.com/Azure/bicep/blob/docs/spec/resource-scopes.md#declaring-the-target-scope
targetScope = 'subscription'

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

@description('The ObjectId of your AzDO DataOps project Service Principal/Service Connection. You will need to update this to the ObjectId of your AzDO Projects Service Principal.')
@secure()
param azdoSpId string

param dateTimeNow string = dateTimeAdd(utcNow(),'PT10H')

var vProject = 'DataOps'
var primaryRegionName = primaryRegion == 'Australia East' ? 'australiaeast' : 'australiasoutheast'
var hubResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-hub'
var spokeResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-spoke1'

// create the required resource groups
resource HubRG 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: hubResourcesRgName
  location: primaryRegionName
  tags: {
    displayName: hubResourcesRgName
    environment: environmentType
    project: vProject
    LastModifiedTime: dateTimeNow
  }
}

resource SpokeRG 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: spokeResourcesRgName
  location: primaryRegionName
  tags: {
    displayName: spokeResourcesRgName
    environment: environmentType
    project: vProject
    LastModifiedTime: dateTimeNow
  }
}

// deploy a module to the hub RG for the rg contents
module HubRG_Content './modules/hub_rg.bicep' = {
  name: 'HubRG_Content'
  scope: HubRG // could use resourceGroup(HubRG.name) for other RG's
  params: {
    environmentAliasPrefix: environmentAliasPrefix
    environmentType: environmentType
    primaryRegion: primaryRegion
    azdoSpId: azdoSpId
  }
}

// deploy a module to the spoke RG for the rg contents
module SpokeRG_Content './modules/spoke_rg.bicep' = {
  name: 'SpokeRG_Content'
  scope: SpokeRG
  params: {
    environmentAliasPrefix: environmentAliasPrefix
    environmentType: environmentType
    primaryRegion: primaryRegion
    azdoSpId: azdoSpId
  }
}
