# this file uploads the template ready to deploy
$projecthome = 'D:\Repos\azdeployrecursive'
$TemplateName = '1deploy\1deploy.json'
$TemplateFile = Join-Path -path $projecthome -ChildPath $TemplateName
$storageName = (New-Guid | ForEach-Object guid).replace('-', '').Substring(0, 22)
$resourceGroupName = 'foo3'
Write-Warning -Message "storageName is [$storageName]"
$location = 'centralus'
$StorageContainerName = 'assets'
New-AzResourceGroup -Name $resourceGroupName -Location $location
New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageName -SkuName Standard_LRS -Location $location -Kind StorageV2
$storage = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageName
New-AzStorageContainer -Name $StorageContainerName -Context $storage.context

Get-ChildItem -Path $projecthome -Filter *.json -Recurse | ForEach-Object {
    $file = $_
    $StorageParams = @{
        File      = $File.FullName
        Blob      = $File.FullName.Substring($projecthome.length + 1)
        Container = $StorageContainerName
        Context   = $storage.Context
        Force     = $true
    }
    Set-AzStorageBlobContent @StorageParams | Select-Object Name, Length, LastModified
}

# now we are ready to deploy

$TemplateArgs = @{ }
$SASParams = @{
    Container  = $StorageContainerName 
    Context    = $storage.Context
    Permission = 'r'
    ExpiryTime = (Get-Date).AddHours(4)
}
$queryString = (New-AzStorageContainerSASToken @SASParams).Substring(1)
$TemplateArgs.Add('queryString', $queryString)

$TemplateURIBase = $storage.Context.BlobEndPoint + $StorageContainerName

Write-Warning -Message "Using template file: [$TemplateFile]"
$TemplateFile = Get-Item -Path $TemplateFile | ForEach-Object FullName
$TemplateFile = $TemplateFile -replace '\\', '/'
$TemplateURI = $TemplateFile -replace ($projecthome -replace '\\', '/'), ''
$TemplateURI = $TemplateURIBase + $TemplateURI
Write-Warning -Message "Ready to deploy via URI: [$TemplateURI]"
$TemplateArgs.Add('TemplateURI', $TemplateURI)
$TemplateArgs.Add('ResourceGroupName', $resourceGroupName)

New-AzResourceGroupDeployment @TemplateArgs -Name deploy -verbose