#!/bin/bash

#Section 1: Create a self-signed root certificate
echo "Creating a self-signed root certificate"
echo "---------------------------------------"

mkdir -p certs

cd certs

# Generate the root key.
openssl genrsa -des3 -out root-ca.key 4096

#Create and self sign the Root Certificate
openssl req -x509 -new -nodes -key root-ca.key -sha256 -days 1024 -out root-cert.crt

# Create  pfx file
openssl pkcs12 -export -out root-cert.pfx -inkey root-ca.key -in root-cert.crt

# Create the certification request. We'll be using the common name of "*.vnet.internal".
openssl req -new -key root-ca.key -out vnet-internal-cert.csr

# Create the vnet-internal certificate.
openssl x509 -req -in vnet-internal-cert.csr -CA root-cert.crt -CAkey root-ca.key -CAcreateserial -out vnet-internal-cert.crt -days 500 -sha256

# Create the pfx file for the vnet-internal certificate.
openssl pkcs12 -export -out vnet-internal-cert.pfx -inkey root-ca.key -in vnet-internal-cert.crt

cd ..

echo "Root certificate and vnet-internal certificate created successfully"

#Section 2: Create resource group in Azure
echo "Creating pre-requisites resources in Azure"
echo "-----------------------------------------"

RESOURCE_GROUP="internal-bicep-rg"
LOCATION="eastus2"

az group create --name $RESOURCE_GROUP --location $LOCATION
az deployment group create --resource-group $RESOURCE_GROUP --template-file ../bicep/pre/main.bicep
az keyvault certificate import --vault-name test-internal-001-kv --name vnet-internal --file vnet-internal-cert.pfx --password "s5p2rm1n"
az keyvault certificate import --vault-name test-internal-001-kv --name root-cert --file root-cert.pfx --password "s5p2rm1n"

echo "Pre-requisite resources created successfully"
echo "-------------------------------------------"

#Section 3: Deploy the Bicep infrastructure
echo "Creating the main infrastructure"
echo "--------------------------------"

az deployment group create --resource-group $RESOURCE_GROUP --template-file ../bicep/infrastructure/main.bicep

echo "Main infrastructure created successfully"
echo "----------------------------------------"

#Section 4: Publish the container images to ACR
echo "Publishing the container images to ACR"
echo "--------------------------------------"

ACR_NAME="testinternalapps0acr"

az acr login --name $ACR_NAME
docker build -t $ACR_NAME.azurecr.io/testing-app:latest ../../../common/app_code/WeatherForecastAPI
docker push $ACR_NAME.azurecr.io/testing-app:latest

#Section 5: Deploy the container apps
echo "Deploying the container apps"
echo "----------------------------"

az deployment group create --resource-group $RESOURCE_GROUP --template-file ../bicep/app/main.bicep

echo "Container apps deployed successfully"
echo "------------------------------------"

#Section 6: Test the public endpoint
PUBLIC_IP_ID=$(az network application-gateway show --resource-group $RESOURCE_GROUP --name test-appGw --query "frontendIPConfigurations[0].publicIPAddress.id" --output tsv)
PUBLIC_IP=$(az network public-ip show --ids $PUBLIC_IP_ID --query "ipAddress" --output tsv)
FINAL_WEATHERFORECAST_URL="http://$PUBLIC_IP/testing-app/weatherforecast"
FINAL_HELLO_URL="http://$PUBLIC_IP/testing-app/hello"