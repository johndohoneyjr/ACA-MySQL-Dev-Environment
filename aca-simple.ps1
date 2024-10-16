# PowerShell script for Drupal 10 on Azure Container Apps
# Database: Azure MySQL

Set-PSDebug -Trace 1


# Set variables
$RG = "abc-drupal-rg"
$LOCATION = "canadacentral"
$ACRNAME = "acacmsacr"
$REGISTRY = "acacmsacr.azurecr.io"
$ACAENV = "acacms-env"
$SA = "acacmsstorageaccount"
$FS = "acacmsfileshare"

# Log in to Azure with the service principal
az login

# Create a resource group
az group create --name $RG --location $LOCATION

# Create ACR
az acr create --resource-group $RG --name $ACRNAME --sku Basic
az acr update -n $ACRNAME --admin-enabled true

# Build and push the image to ACR
az acr build --image "$REGISTRY/acacms:latest" --registry $ACRNAME --file Dockerfile .

# Create an Azure Container App Environment
az containerapp env create --name $ACAENV --resource-group $RG --location $LOCATION

# Get ACR credentials
$ACR_PASSWORD = az acr credential show --name $ACRNAME --query "passwords[0].value" --output tsv

# Remove '/r' from the password
$ACR_PASSWORDNOR = $ACR_PASSWORD -replace "`r", ""

# Create Container App, save the MySql URL in the environment variable
az containerapp create --name mydrupalapp --resource-group $RG --environment $ACAENV `
 --image "$REGISTRY/acacms:latest" --target-port 80 --ingress external `
 --registry-server $REGISTRY --registry-username $ACRNAME --registry-password $ACR_PASSWORDNOR `
 --env-vars DATABASE_URL="mysql://myadmin:Abe$12superSecret@acacmsMySqlServer.mysql.database.azure.com:3306/drupaldb"

 az containerapp show --name mydrupalapp --resource-group $RG --query properties.configuration.ingress.fqdn --output tsv

################ MySQL Configuration ################
# Create a MySQL database
az mysql flexible-server create --resource-group $RG --name acacmsMySqlServer --location $LOCATION `
 --admin-user myadmin --admin-password "Abe$12superSecret" --sku-name Standard_B1ms --storage-size 32

# Create a MySQL database
az mysql flexible-server db create --resource-group $RG --server-name acacmsMySqlServer --database-name drupaldb
