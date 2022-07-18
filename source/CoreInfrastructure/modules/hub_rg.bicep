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
param azdoSpId string // (az ad sp show --id $sp.appId | ConvertFrom-Json).objectId

var primaryRegionName = primaryRegion == 'Australia East' ? 'australiaeast' : 'australiasoutheast'
var hubResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-hub'
var spokeResourcesRgName = '${environmentAliasPrefix}-DemoEnv-${environmentType}-spoke1'
var rgContributorId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // (Get-AzRoleDefinition -Name Contributor).Id
var sharedLawsName = '${environmentAliasPrefix}-sharedlaws-${environmentType}'
var OMSSolutionNames = [
  'AzureDataFactoryAnalytics'
  'AzureSQLAnalytics' // for other monitoring options, look here - https://docs.microsoft.com/en-us/azure/azure-sql/database/monitor-tune-overview?view=azuresql
  // 'SQLAuditing'
  'SQLAdvancedThreatProtection'
  'SQLVulnerabilityAssessment'
  'Security'
  // KeyVaultAnalytics // KV Analytics Solution is deprecated. https://docs.microsoft.com/en-us/azure/azure-monitor/insights/key-vault-insights-overview. We recommend using Key Vault Insights. https://docs.microsoft.com/en-us/azure/azure-monitor/insights/key-vault-insights-overview
]

resource AzureDevOpsPipeline_RGContributorPermission 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(hubResourcesRgName, subscription().id, azdoSpId)
  properties: {
    principalId: azdoSpId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${rgContributorId}'
  }
}

resource sharedLAWS 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: sharedLawsName
  location: primaryRegionName
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource OMSSolutions 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for SolutionName in OMSSolutionNames: {
  name: '${SolutionName}(${sharedLawsName})'
  location: primaryRegionName
  properties: {
    workspaceResourceId: sharedLAWS.id
  }
  plan: {
    name: '${SolutionName}(${sharedLawsName})'
    product: 'OMSGallery/${SolutionName}'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}]

output sharedLawsId string = sharedLAWS.id
