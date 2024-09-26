#!/bin/bash

mkdir -p certs

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