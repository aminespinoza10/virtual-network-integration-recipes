# Azure Container Apps with Internal API Management and Application Gateway

## Scenario

This recipe addresses a scenario where there is a requirement to restrict HTTP/S access to an Azure Container App to a specific virtual network, while providing advanced security and networking functionality like network security groups, ssl offloading, etc. In this scenario, clients will be capable of accessing the resources by pointing to App Gateway without any problem and by not letting them access any other resources from the system.

The Container App is configured with an internal [custom domain](https://learn.microsoft.com/azure/dns/private-dns-privatednszone) and can be accesed from API Management this way, APIM is then ready to be accessed trough App Gateway using the same custom domain.

> The core of all of this is the Private DNS Zone this functionality and a good configuration with Network Security Groups are the perfect mix to make it, in this sample we'll be using a domain like *.vnet.internal

API Management and Application Gateway services allow for a custom security profile for the Azure Container App when used in tandem. An API Management instance in internal mode is placed in front of the Azure Container App and controls all traffic that is routed to the API from within the network. API callers from within the virtual network are able to access the Container App via the API Management endpoints. An Application Gateway handles ingress into the network and routes requests from outside of the virtual network to the API Management instance.

### Problem Summary

There are multiple challenges to configuring an Container App to be accessible only via a private virtual network or from a set of trusted partners:

- Configuration of the Container App Environment ingress only inside of a VNET.
- Linking the Container App to API Management using the correct policies.
- Deploying application automatically without a problem.
- Creation and management of certificates for custom domains.
- Configuration of the connection between Application Gateway and API Management.

This recipe attempts to make such configuration easier by providing both Terraform and Bicep assets to serve as a starting point to understand how to configure the whole system with additional layers of security and functionality provided by API Management and Application Gateway.

### Architecture

![Azure Web App with private HTTP endpoint](./media/containerapps-internal.png)

### Recommendations

The following sections provide recommendations on when this recipe should, and should not, be used.

#### Recommended

This recipe is recommended if the following conditions are true:

- The Azure Container App can be reached inside of the virtual network for developing purposes.
- Private (virtual network) connectivity to the Azure Key Vault used for persisting application secrets.
- Ability to use Azure Private DNS Zones.
- Ability to use a Network Security Group.
- Requirement to apply custom API Management policies like rate limiting, caching, etc.
- Customizable Application Gateway rules to make the services accesible from public networks.

#### Not Recommended

This recipe is **not** recommended if the following conditions are true:

- Azure Container App HTTP/S endpoint is accessible from the public Internet.

## Getting Started

The following sections provide details on pre-requisites to use the recipe, along with deployment instructions.

### Pre-requisites

The following pre-requisites should be in place in order to successfully use this recipe:

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- An active Azure Subscription.
- Terraform installed (if you want to deploy with Terraform).

### Deployment

To deploy this recipe, perform the infrastructure deployment steps using _either_ Terraform or Bicep in the expected order to make everything go great.

### Remote Access

The recipe does not provision a Virutal Machine (VM) or Azure Bastion to provide remote access within the virtual network. Nevertheless, there is an extra subnet already being created for the VM, the subnet name is **apps-subnet**, however if you want to create a bastion instance you'll need to create it and let bastion create the needed subnet.

### Virtual Network

The recipe provides a virtual network with 5 different subnets. The recipe creates an Azure Private DNS zone to work with all required features in a simple topology letting them working in coordinationwithout a problem, in order to create the DNS Zone with certificates you'll need to create them and then add them to the Private Zone.

### Create Certificates for API Management Custom Domains

API Management is able to expose endpoints using a custom domain rather than the default `azure-api.net` subdomain that is assigned to the service. In this recipe, custom domains are used in order to allow the user to expose an API using the same domain name both _inside_ and _outside_ the virtual network. Inside the virtual network, the custom domains map directly to the API Management private IP address. The domains are mapped to the Application Gateway public IP address for calls originating from outside the virtual network. The recipe assumes that the user possesses the server certificates for the Gateway, Portal, and Management endpoints on for the API Management instance, and the root certificate used to sign those requests. The [create-certificates.sh](./deploy/bash/create-certificates.sh) script provides openssl commands to create and self-sign the required certificates.

It is important to prefix your domain with *, so the same generated domain cert may be used for all the different sub domains.
The script creates a `.certs` folder that contains each of the `.pfx` certificates for the API Management custom domains and the `.crt` file for the root.

### Deploying the architecture

No matter which way you want to go, Bicep or Terraform  go to the folder **pre** to deploy the following set of tools.

- Azure Container Registry
- Azure Managed Identity
- Key Vault
- Log Analytics Workspace

**Note**: We are not using modules as a best practice for Terraform or Bicep just to make the projects more readable and not adding a layer of unnecesary complexity.

