#!/bin/bash

#Section 1: Create a self-signed root certificate
echo "Step 1: Creating a self-signed root certificate"
echo "---------------------------------------"

DIRECTORY_NAME="certs"

if [ -d "$DIRECTORY_NAME" ]; then
  echo "Directory $DIRECTORY_NAME already exists. Skipping certificate creation."
else
  echo "Directory $DIRECTORY_NAME does not exist. Creating directory and generating certificates."

  mkdir -p "$DIRECTORY_NAME"
  cd "$DIRECTORY_NAME" || exit 1

  echo "Creating the root certificate and vnet-internal certificate"
  echo "-----------------------------------------------------------"

  # Generate the root key.
  openssl genrsa -des3 -out root-ca.key 4096

  # Create and self sign the Root Certificate
  openssl req -x509 -new -nodes -key root-ca.key -sha256 -days 1024 -out root-cert.crt

  # Create pfx file
  openssl pkcs12 -export -out root-cert.pfx -inkey root-ca.key -in root-cert.crt

  # Create the certification request. We'll be using the common name of "*.vnet.internal".
  openssl req -new -key root-ca.key -out vnet-internal-cert.csr

  # Create the vnet-internal certificate.
  openssl x509 -req -in vnet-internal-cert.csr -CA root-cert.crt -CAkey root-ca.key -CAcreateserial -out vnet-internal-cert.crt -days 500 -sha256

  # Create the pfx file for the vnet-internal certificate.
  openssl pkcs12 -export -out vnet-internal-cert.pfx -inkey root-ca.key -in vnet-internal-cert.crt

  cd ..
fi

echo "Root certificate and vnet-internal certificate created successfully"

CERT_DIR="./certs"
ROOT_CERT="$CERT_DIR/root-cert.pfx"
VNET_INTERNAL_CERT="$CERT_DIR/vnet-internal-cert.pfx"

if [[ ! -f "$ROOT_CERT" || ! -f "$VNET_INTERNAL_CERT" ]]; then
  echo "Error: Certificates not found. Please ensure that the certificates are created and located in the $CERT_DIR directory."
  exit 1
fi

#Section 2: Create resource group in Azure
echo "Step 2: Creating pre-requisites resources in Azure"
echo "-----------------------------------------"

RESOURCE_GROUP="internal-bicep-rg"
LOCATION="eastus2"

az group create --name $RESOURCE_GROUP --location $LOCATION


DEPLOYMENT_OUTPUT=$(az deployment group create --resource-group $RESOURCE_GROUP --template-file ../bicep/pre/main.bicep --query "properties.outputs")

KEY_VAULT_NAME=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.keyVaultName.value')

USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)
az keyvault set-policy --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --object-id "$USER_OBJECT_ID" --certificate-permissions import --key-permissions import --secret-permissions set
az keyvault certificate import --vault-name "$KEY_VAULT_NAME" --name vnet-internal-cert --file ./certs/vnet-internal-cert.pfx --password "s5p2rm1n"
az keyvault certificate import --vault-name "$KEY_VAULT_NAME" --name root-cert --file ./certs/root-cert.pfx --password "s5p2rm1n"
az keyvault delete-policy --name "$KEY_VAULT_NAME" --object-id "$USER_OBJECT_ID"

echo "Pre-requisite resources created successfully"
echo "-------------------------------------------"

#Section 3: Deploy the Bicep infrastructure
echo "Creating the main infrastructure"
echo "--------------------------------"

# Progress bar for 30 seconds
echo -n "Waiting for 30 seconds: "
for i in {1..30}; do
  printf "\rWaiting for 30 seconds: %2d seconds elapsed $i"
  sleep 1
done
echo ""

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
PUBLIC_IP=$(az network public-ip show --ids "$PUBLIC_IP_ID" --query "ipAddress" --output tsv)
FINAL_WEATHERFORECAST_URL="http://$PUBLIC_IP/testing-app/weatherforecast"
FINAL_HELLO_URL="http://$PUBLIC_IP/testing-app/hello"

echo "$FINAL_WEATHERFORECAST_URL"
echo "$FINAL_HELLO_URL"