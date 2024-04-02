
//az deployment group create -g rg-mawi -f main.bicep 
// az group create -n rg-mawi -l swedencentral
// az storage blob service-properties update --account-name stgmawi1234 --static-website  --index-document index.html
// az storage blob upload-batch --account-name stgmawi1234 --destination '$web' --source dist/mawi-app

param name string  = 'mawi'
param location string = resourceGroup().location

param deployafd bool = false
param deploywaf bool = false
param deployapi bool = false
param deployruleset bool = false

// Storage account 
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'stg${name}1234'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

// Log analytics workspace
resource la 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'la-${name}'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}


// Azure Front Door
resource afd 'Microsoft.Cdn/profiles@2023-07-01-preview' = if(deployafd){
  name: 'afd-${name}'
  location: 'Global'
  sku: {
    name:'Premium_AzureFrontDoor'
  }
}

// AFD Endpoint
resource afd_endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-07-01-preview' = if(deployafd){
  name: 'ep-${name}'
  location: 'Global'
  parent: afd
  properties: {
    enabledState:'Enabled'
  }
}


// Web Origin group
resource afd_origin_group_default 'Microsoft.Cdn/profiles/originGroups@2023-07-01-preview' = if(deployafd){
  name: 'origin-group-default' 
  parent: afd
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100

    }
  }
}


// Web Origin
resource afd_origin_default 'Microsoft.Cdn/profiles/originGroups/origins@2023-07-01-preview' = if(deployafd){
  name: 'origin-default'
  parent: afd_origin_group_default
  properties: {
    hostName: '${storage.name}.z1.web.${environment().suffixes.storage}'
    enabledState:'Enabled'
    httpPort:80
    httpsPort:443
    priority:1
    weight:1000
    originHostHeader:'${storage.name}.z1.web.${environment().suffixes.storage}'
    enforceCertificateNameCheck: true
    
  }
}


// Route to web origin
resource afd_route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-07-01-preview' = if(deployafd){
  name: 'route-${name}'
  parent:afd_endpoint
  properties: {
    originGroup:{
      id: afd_origin_group_default.id

    }
    linkToDefaultDomain: 'Enabled'

    originPath: '/browser'
    supportedProtocols: [
      'Https'
    ]
    enabledState:'Enabled'
    forwardingProtocol:'MatchRequest'
    httpsRedirect:'Enabled'
  }
}


// Diagsettings for AFD
resource la_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(deployafd){
  scope: afd
  name: 'diagnosticSettings'
  properties: {
    workspaceId: la.id
    logs: [
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: true
        }
      }
      {
        category: 'FrontDoorAccessLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: true
        }
      }
    ]
  }
}




// Firewall policy
resource waf_policy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = if(deploywaf){
  name: 'wafpolicy${name}'

  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {

    policySettings: {
      enabledState:'Enabled'
      mode:'Detection'
      requestBodyCheck:'Enabled'
    }

    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction:'Block'
        }
        
      ]
    }
  }
}

// AFD security policy
resource afd_security_policy 'Microsoft.Cdn/profiles/securityPolicies@2023-07-01-preview' = if(deploywaf){
  name: 'policy-${name}'
  parent: afd
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
         id: waf_policy.id
      }
      associations: [
        {
          domains: [
            {
              id: afd_endpoint.id
            }

          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}


// API Management 
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: 'apim-${name}'
  location: location
  sku: {
    capacity: 0
    name: 'Consumption'
  }
  properties: {
    publisherEmail: 'jonas.norlund@microsoft.com'
    publisherName: 'Microsoft'
  }
}

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' existing = {
  name: 'master'
  parent:apim
}


// APIM Origin group
resource afd_origin_group_apim 'Microsoft.Cdn/profiles/originGroups@2023-07-01-preview' = if(deployapi){
  name: 'origin-group-apim' 
  parent: afd
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/status-0123456789abcdef'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
  }
}

// APIM Origin
resource afd_origin_apim 'Microsoft.Cdn/profiles/originGroups/origins@2023-07-01-preview' = if(deployapi){
  name: 'origin-apim'
  parent: afd_origin_group_apim
  properties: {
    hostName: 'apim-${name}.azure-api.net'
    enabledState:'Enabled'
    httpPort:80
    httpsPort:443
    priority:1
    weight:1000
    originHostHeader:'apim-${name}.azure-api.net'
    enforceCertificateNameCheck: true

    
  }
}

// APIM Route
resource afd_route_apim 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-07-01-preview' = if(deployapi){
  name: 'route-${name}-apim'
  parent:afd_endpoint
  properties: {
    originGroup:{
      id: afd_origin_group_apim.id
    }
    patternsToMatch: [
      '/api/*'
    ]
    linkToDefaultDomain: 'Enabled'
    originPath: '/'
    supportedProtocols: [
      'Https'
    ]
    enabledState:'Enabled'
    forwardingProtocol:'MatchRequest'
    httpsRedirect:'Enabled'

    // ruleSets: [
    //    {
    //      id: ruleSet.id
    //    }
    // ]
  }
  dependsOn: [
    afd_origin_apim
  ]
}





// APIM Ruleset
resource ruleSet 'Microsoft.Cdn/profiles/ruleSets@2021-06-01' = if(deployruleset){
  name: 'apimruleset'
  parent: afd
}


  

resource rule_rewrite 'Microsoft.Cdn/profiles/ruleSets/rules@2023-07-01-preview' = if(deployruleset){
  name: 'urlrewrite'
  parent: ruleSet
  properties: {
    order: 1
    actions: [
      {
        name: 'UrlRewrite'
        parameters: {
          destination: '/swapi/api/'
          sourcePattern: '/'
          typeName: 'DeliveryRuleUrlRewriteActionParameters'
          preserveUnmatchedPath: true
        }
      }
      {
        name: 'ModifyRequestHeader'
        parameters: {
          headerAction: 'Append'
          headerName: 'Ocp-Apim-Subscription-Key'
          typeName: 'DeliveryRuleHeaderActionParameters'
          value: subscription.listSecrets().primaryKey
        }
      }
    ]
  }
}


  

