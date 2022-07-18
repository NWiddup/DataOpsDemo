param(
  [string]$environment = "dev"
  ,[string]$sourceFilepath = '.\reference\' # '$(Build.SourcesDirectory)\reference\'
  ,[string]$sourceFilename = 'Financial Sample.xlsx'
  ,[string]$resourceGroupName = "ResourceGroup$($environment)"
  ,[string]$destStorageAccountName = "storageacct$($environment)"
  ,[string]$destContainerName = 'source'
)

$fullpath = Join-Path $sourceFilepath $sourceFilename

$res = Get-Module Az.Storage -ListAvailable
if (!($res)) {
    Write-Output "Installing Module Az.Storage..."
    Install-Module Az.Storage -Confirm -AllowClobber
    Write-Output "Installed Module Az.Storage"
}
Import-Module Az.Storage

# $storageAccount = Get-AzStorageAccount -ResourceGroupName \"[resourceGroup().name]\" -Name \"[parameters('storageAccountName')]\"
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $destStorageAccountName

$BlobParameters = @{
    File             = $fullpath
    Container        = $destContainerName
    Blob             = $sourceFilename
    Context          = $storageAccount.Context 
    StandardBlobTier = 'Hot'
}

Set-AzStorageBlobContent @BlobParameters -Force
