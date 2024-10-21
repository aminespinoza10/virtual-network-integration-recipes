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

#Section 2: Create pre-requisites resources in Azure
echo "Creating pre-requisites resources in Azure"
echo "-----------------------------------------"

cd ../terraform/pre

terraform init 

terraform plan -out=plan.out

terraform apply plan.out

echo "Pre-requisite resources created successfully"
echo "-------------------------------------------"

#Section 3: Deploy the Terraform infrastructure
echo "Creating the main infrastructure"
echo "--------------------------------"

cd ../terraform/infrastructure

terraform init 

terraform plan -out=plan.out

terraform apply plan.out

#Section 4: Publish the container images to ACR

#Section 5: Deploy the container apps

#Section 6: Test the public endpoint
