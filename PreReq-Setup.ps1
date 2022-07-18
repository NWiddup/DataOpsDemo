[CmdletBinding()]
param (
     $azdoOrgName="azdoOrgName",
     $azdoProjectName="azdoProjectName",
     $azSubscriptionName="azSubscriptionName",
     $environmentAliasPrefix="environmentAliasPrefix",
     $primaryRegion="Australia East",
     $environments=$('dev','test','prod')
)

$org = "https://dev.azure.com/$azdoOrgName"

# add azure devops extension to az cli
az extension add --name azure-devops

# set default azdo organization
az devops configure --defaults organization=$org

$project = (az devops project show --project $azdoProjectName --org $org) | ConvertFrom-Json

Write-Host $project
# create new project
if ($null -eq $project)
{
     az devops project create --name $azdoProjectName --org $org
}
# set default project to above
az devops configure --defaults organization=$org project=$azdoProjectName

# get Azure subscription info
$account = (az account show) | ConvertFrom-Json

$sp = az ad sp list --display-name "Azdo-${azdoOrgName}-${azdoProjectName}-Sp" | ConvertFrom-Json
if (!($sp)) {
     # create new service principal for azure devops service end-point
     $sp = (az ad sp create-for-rbac -n "Azdo-${azdoOrgName}-${azdoProjectName}-Sp") | ConvertFrom-Json

     $env:AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY = $sp.password
}

$endpoint = az devops service-endpoint list --org $org --project $azdoProjectName | convertfrom-json

if (!($endpoint)) {
     $endpoint = az devops service-endpoint azurerm create --name "${azdoProjectName}AzSvcEndpoint" `
          --azure-rm-tenant-id $account.tenantId `
          --azure-rm-service-principal-id $sp.appId `
          --azure-rm-subscription-id $account.id `
          --azure-rm-subscription-name $account.name `
          --org $org --project $azdoProjectName

     az devops service-endpoint list --org $org --project $azdoProjectName
}

# normally we recommend following the methodology in the Secure CAF Governance, with different service principals having different elevations (one for RG creation, one for spoke/solution deployment). 
# https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/secure/best-practices/end-to-end-governance
# however, for this sample demo, we will add the service principal to the Owner role of the subscription, so it can perform all the deployments for us
az role assignment create --assignee-object-id $spInfo.objectId --role "Owner" --scope "/subscriptions/$($account.id)"

# create the pipeline folders
az pipelines folder create --path "IAC Pipelines" --description "Folder to hold the IAC pipelines"
az pipelines folder create --path "DataOps Pipelines" --description "Folder to hold the IAC pipelines"

# create the CICD pipelines
# you WILL need to authorize the pipelines to use the Service Connection before their first run
$pipelinesToCreate = @(
     @{
          plName = 'Build-IAC-CoreInfrastructure'
          plDescription = 'Pipeline to perform builds of the Bicep files for the Core Infrastructure'
          plYamlPath = 'pipelines/iac_core_build.yaml'
          plFolderPath = 'IAC Pipelines'
     },
     @{
          plName = 'Build-IAC-SolutionInfrastructure'
          plDescription = 'Pipeline to perform builds of the Bicep files for the Solution Infrastructure'
          plYamlPath = 'pipelines/iac_solution_build.yaml'
          plFolderPath = 'IAC Pipelines'
     },
     @{
          plName = 'Deploy-IAC-CoreInfrastructure'
          plDescription = 'Pipeline to perform deployment of the Bicep files for the Core Infrastructure'
          plYamlPath = 'pipelines/iac_core_deploy.yaml'
          plFolderPath = 'IAC Pipelines'
     },
     @{
          plName = 'Deploy-IAC-SolutionInfrastructure'
          plDescription = 'Pipeline to perform deployment of the Bicep files for the Solution Infrastructure'
          plYamlPath = 'pipelines/iac_solution_deploy.yaml'
          plFolderPath = 'IAC Pipelines'
     }
     # ,@{
     #      plName = 'Build-ADF-classic'
     #      plDescription = 'Pipeline to perform builds of the JSON files for ADF'
     #      plYamlPath = 'pipelines/adf-classic_build.yaml'
     #      plFolderPath = 'DataOps Pipelines'
     # }
     # ,@{
     #      plName = 'Deploy-ADF-classic'
     #      plDescription = 'Pipeline to perform deployment of the JSON files for ADF'
     #      plYamlPath = 'pipelines/adf-classic_deploy.yaml'
     #      plFolderPath = 'DataOps Pipelines'
     # }
     # ,@{
     #      plName = 'Build-SqlDb_SimpleSamples'
     #      plDescription = 'Pipeline to perform builds of the SSDT files for SimpleSamples DB'
     #      plYamlPath = 'pipelines/sqldb_simplesamples_build.yaml'
     #      plFolderPath = 'DataOps Pipelines'
     # }
     # ,@{
     #      plName = 'Build-SqlDb_ADFMetadataDb'
     #      plDescription = 'Pipeline to perform builds of the SSDT files for ADFMetadataDb DB'
     #      plYamlPath = 'pipelines/sqldb_adfmetadata_build.yaml'
     #      plFolderPath = 'DataOps Pipelines'
     # }
     # ,@{
     #      plName = 'Deploy-SqlDb_SimpleSamples'
     #      plDescription = 'Pipeline to perform deployment of the DACPAC files for SimpleSamples'
     #      plYamlPath = 'pipelines/sqldb_simplesamples_deploy.yaml'
     #      plFolderPath = 'DataOps Pipelines'
     # }
     # ,@{
     #      plName = 'Deploy-SqlDb_ADFMetadataDb'
     #      plDescription = 'Pipeline to perform deployment of the DACPAC files for ADFMetadataDb DB'
     #      plYamlPath = 'pipelines/sqldb_adfmetadata_deploy.yaml'
     #      plFolderPath = 'DataOps Pipelines'
     # }
)

foreach ($p in $pipelinesToCreate) {
     # Update this information as required (eg. if you are using a GitHub repo instead of an AzDO repo)
     $p += @{
          plRepoType = 'tfsgit'
          plProject = $azdoProjectName
          plRepository = $azdoProjectName
          plBranch = 'main'
          plServiceConnection = "${azdoProjectName}AzSvcEndpoint"           
     }

     az pipelines create --name $p.plName `
          --description $p.plDescription `
          --yaml-path $p.plYamlPath `
          --repository-type $p.plRepoType `
          --project $p.plProject `
          --repository $p.plRepository `
          --branch $p.plBranch `
          --folder-path $p.plFolderPath `
          --service-connection $p.plServiceConnection `
          --skip-first-run true
}
     
if (!($objectId)) {
     $detailSp = (az ad sp show --id $sp.appId) | ConvertFrom-Json
     $objectId = $detailSp.objectId
}

foreach ($envName in $environments) {
     az deployment sub create --location $primaryRegion -f ./source/CoreInfrastructure/iac_subscription_main.bicep --parameters environmentAliasPrefix=$environmentAliasPrefix environmentType=$envName primaryRegion=$primaryRegion azdoSpId=$objectId
}
