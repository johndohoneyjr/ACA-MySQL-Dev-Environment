# PowerShell script for Drupal 10 on Azure Container Apps
# Database: Azure MySQL

Set-PSDebug -Trace 1


# Set variables
$RG = "jd-drupal-rg"
$LOCATION = "canadacentral"
$ACRNAME = "dohoneyacr"
$REGISTRY = "$ACRNAME.azurecr.io"
$ACAENV = "acacms-env"
$SA = "cmsstorageaccount"
$FS = "cmsfileshare"
$STORAGE_MOUNT_NAME="mydrupalstoragemount"
$ENVIRONMENT_NAME="cmsstorageenvironment"
$CONTAINER_APP_NAME="mydrupalapp"
################ MySQL Configuration ################
$DB_SERVER_NAME="acaMySqlServer"
$DRUPAL_DB_HOST="$DB_SERVER_NAME.mysql.database.azure.com"
$DB_SERVER_SKU="Standard_B1ms"
$DRUPAL_DB_USER="myAdmin"
$DRUPAL_DB_PASSWORD="Abe$12superSecret"
$DRUPAL_DB_NAME="drupal_db"
$MIN_REPLICAS="1"
$MAX_REPLICAS="3"
$SUBSCRIPTION="f74853cf-a2a4-43b0-953d-651aaf3bd314"

# Log in to Azure with the service principal
az login

az account set --subscription $SUBSCRIPTION
# Create a resource group
az group create --name $RG --location $LOCATION

# Create ACR
az acr create --resource-group $RG --name $ACRNAME --sku Basic
az acr update -n $ACRNAME --admin-enabled true

# Create an Azure Container App Environment
az containerapp env create `
--name $ACAENV `
--resource-group $RG `
--location $LOCATION

$ENVIRONMENT_ID = $(az containerapp env show `
  --name $ACAENV `
  --resource-group $RG `
  --query "id" `
  --output tsv)

Write-Output $ENVIRONMENT_ID

# Create a randowm number 4 digits long
$RANDOM_NUMBER = Get-Random -Minimum 1000 -Maximum 9999
# Append the random number to the $SA variable
$SARAND = $SA + $RANDOM_NUMBER

# Create an Azure Storage Account
az storage account create `
 --name $SARAND `
 --resource-group $RG `
 --location $LOCATION `
 --sku Standard_LRS `
 --kind StorageV2 `
 --enable-large-file-share `
 --query provisioningState

# Get the account key
$account_key = az storage account keys list --resource-group $RG --account-name $SARAND --query "[0].value" --output tsv

# Create a File Share
$share_exists = az storage share exists --name $FS --account-name $SARAND --account-key $account_key --query exists

if ($share_exists -eq "false") {
    az storage share create --name $FS --account-name $SARAND --account-key $account_key
} else {
    Write-Output "The storage share $FS already exists."
}

az containerapp env storage set `
  --access-mode ReadWrite `
  --azure-file-account-name $SARAND `
  --azure-file-account-key $account_key `
  --azure-file-share-name $FS `
  --storage-name $STORAGE_MOUNT_NAME `
  --name $ACAENV `
  --resource-group $RG `
  --output table

# Create a MySQL database
az mysql flexible-server create `
 --resource-group $RG `
 --name $DB_SERVER_NAME `
 --location $LOCATION `
 --admin-user myadmin `
 --admin-password "Abe$12superSecret" `
 --sku-name Standard_B1ms --storage-size 32

# Create a MySQL database
az mysql flexible-server db create `
--resource-group $RG `
--server-name $DB_SERVER_NAME `
--database-name $DRUPAL_DB_NAME


$storageMountYaml = @"
location: $LOCATION
name: $CONTAINER_APP_NAME
resourceGroup: $RG
type: Microsoft.App/containerApps
properties:
  managedEnvironmentId: $ENVIRONMENT_ID
  configuration:
    activeRevisionsMode: Single
    dapr: null
    ingress:
      external: true
      allowInsecure: false
      targetPort: 8080
      traffic:
        - latestRevision: true
          weight: 100
      transport: Auto
    registries: null
    secrets:
      - name: drupal-db-name
        value: $DRUPAL_DB_NAME
      - name: drupal-db-password
        value: $DRUPAL_DB_PASSWORD
      - name: drupal-db-user
        value: $DRUPAL_DB_USER
      - name: drupal-db-host
        value: $DRUPAL_DB_HOST

    service: null
  template:
    revisionSuffix: ''
    containers:
      - image: docker.io/bitnami/drupal:10.3.6-debian-12-r1
        name: drupal
        env:
        - name: $DRUPAL_DATABASE_NAME
          secretRef: drupal-db-name
        - name: "$DRUPAL_DATABASE_PASSWORD"
          secretRef: drupal-db-password
        - name: $DRUPAL_DATABASE_USER
          secretRef: drupal-db-user
        - name: $DRUPAL_DATABASE_PORT_NUMBER
          value: '3306'
        - name: DRUPAL_DATABASE_HOST
          secretRef: drupal-db-host
        resources:
          cpu: 2
          ephemeralStorage: 8Gi
          memory: 4Gi
        volumeMounts:
        - mountPath: /bitnami/drupal
          volumeName: mystoragemount
    volumes:
    - name: mystoragemount
      storageName: $STORAGE_MOUNT_NAME
      storageType: AzureFile
    scale:
      minReplicas: $MIN_REPLICAS
      maxReplicas: $MAX_REPLICAS
"@

$storageMountYaml | Out-File -FilePath aca-DoNotCheckIn.yaml -Encoding utf8

 

az containerapp create `
-n $CONTAINER_APP_NAME `
-g $RG `
--environment $ACAENV  `
--yaml aca-DoNotCheckIn.yaml `
--query properties.configuration.ingress.fqdn

 az containerapp show --name mydrupalapp --resource-group $RG --query properties.configuration.ingress.fqdn --output tsv





# # Test the file mount
# az containerapp exec --name mydrupalapp --resource-group $RG --command "/bin/sh"
# # Navigate to the mount path
# Set-Location /var/www/html/sites/default/files

# # Create a test file
# Write-Output "This is a test file" > testfile.txt

# # List files to verify
# Get-ChildItem -Path .