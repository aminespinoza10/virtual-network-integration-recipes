# Azure ContainerApp deployed in VNET

## Scenario



### Problem Summary


### Architecture

![Azure ContainerApp deployed in VNET](./media/private-containerapp-http.png)

### Recommendations


#### Recommended


#### Not Recommended


## Getting Started


### Pre-requisites



### Deployment

```bash
# deploy initial infrastructure
export DEPLOYMENTNAME=az-containerapp2
az deployment sub create --name $DEPLOYMENTNAME --location australiaeast --template-file main.bicep --parameters @azuredeploy.parameters.sample.json

# deploy new container image and update containerapp revision
registry=$(az deployment sub show --name $DEPLOYMENTNAME --query 'properties.outputs.azure_artefact_registry_endpoint.value' -o tsv)
az acr login -n $registry
containerImageTag=simple-fastapi:latest
docker buildx create --name=buildkit-container --driver=docker-container --driver-opt "image=moby/buildkit:v0.11.2,network=host" --bootstrap --use
docker buildx build --tag $registry/$containerImageTag --attest type=sbom --push ../../../common/app_code/simple-fastapi/
resourcegrupname=$(az deployment sub show --name $DEPLOYMENTNAME --query 'properties.outputs.resource_group_name.value' -o tsv)
containerappname=$(az deployment sub show --name $DEPLOYMENTNAME --query 'properties.outputs.container_app_name.value' -o tsv)
az containerapp update -n $containerappname  -g $resourcegrupname --image $registry/$containerImageTag
```



### Remote Access


#### Virtual Network


#### Deploying Infrastructure Using Bicep


#### Deploying Web Application Code



### Testing Solution


## Change Log



## Next Steps
