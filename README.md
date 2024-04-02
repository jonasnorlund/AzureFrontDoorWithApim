# AzureFrontDoorWithApim

Decide a suffix for the solution, it should contain four letters, eg. "mawi". Whenever [suffix] is used below, replace the [suffix] with the four letters.  

### 1. Create an Angular app
Navigate to the apps folder and create a new app. Choose CSS as stylesheet and enable SSR. 

`` ng new [suffix]-app``

### 2. Create a resourcegroup in Azure
`` az group create -n rg-[suffix] -l swedencentral``


### 3. Create storage account using bicep
Open the main.bicep file and change the default value for the name parameter to the [suffix] that has been chosen. Navigate to the bicep folder and run the following command. 

`` az deployment group create -g rg-[suffix] -f main.bicep``


### 4. Update storageaccount to enable static website using cli
Run the following command. 
    
`` az storage blob service-properties update --account-name stg[suffix]1234 --static-website  --index-document index.html``
 
### 5. Publish site to the storageaccount using cli
Navigate to the app folder and run the following commands. 

`` ng build ``<br>
``az storage blob upload-batch --account-name stg[suffix]1234 --destination '$web' --source dist/[suffix]-app ``
If changes are made to the code and the command needs to be run again, run the following command first. 

``az storage blob delete-batch --account-name stg[suffix]1234 --source '$web' ``

### 6. Browse to site
Use a browser and navigate to the app https://stg[suffix]1234.z1.web.core.windows.net/browser 

### 7. Create a Azure Front Door (AFD) service in front of the storageaccount
Create a Azure Front Door service with the following configuration using bicep
* origin group
* origin
* endpoint
* route

Open main.bicep and set the "deployafd" parameter to true, navigate to the bicep folder and run the command.

`` az deployment group create -g rg-[suffix] -f main.bicep``

### 8. Browse to site through AFD
Use a browser and navigate to the app using the afd endpoint address. Get the endpoint address through the Azure portal, copy the "Endpoint hostname" https://ep-[suffix]-[generated letters].b01.azurefd.net


### 9. Deploy Web Application Firewall (WAF) policies
Open main.bicep and set the "deploywaf" parameter to true, navigate to the bicep folder and run the command.

`` az deployment group create -g rg-[suffix] -f main.bicep``

### 10. Add API in API Management (APIM)
Go to the Azure portal and find the API Management instance "apim-[suffix]. Goto "APIs", choose OpenAPI, click on "Select a file", choose the file "swapi.json" in the bicep folder, enter "swapi" as the API URL suffix, click Create. 

An API has been created. 


### 11. Add another origin in AFD for the API 
Open main.bicep and set the "deployapi" parameter to true, navigate to the bicep folder and run the command.

`` az deployment group create -g rg-[suffix] -f main.bicep``

Use a browser or a REST client and navigate to https://ep-[suffix]-[generated letters].b01.azurefd.net/api/people/1 

It fails, check the logs in log analytics, check the value in the field "originUrl_s". 

### 12. Create a ruleset in AFD

Find the commented lines in main.bicep and uncomment them. 
    
    
    // ruleSets: [
    //    {
    //      id: ruleSet.id
    //    }
    // ]
    
Set the "deployruleset" parameter to true and run the command.  

`` az deployment group create -g rg-[suffix] -f main.bicep`` 

### 12. Test the api through AFD

Use a browser or a REST client and navigate to https://ep-[suffix]-[generated letters].b01.azurefd.net/api/people/1


