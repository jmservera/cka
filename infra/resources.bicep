param location string = resourceGroup().location
param vscodeDomainNameLabel string = 'vscode'
param clusterDomainNameLabel string = 'cluster'
param environmentName string = resourceGroup().tags['azd-env-name'] ?? 'default-env'
param resourceToken string = toLower(uniqueString(subscription().id, environmentName, location))
@secure()
param vscodeServerToken string
param vmSize string = 'Standard_D8as_v5'
param tags object = {
  'azd-env-name': environmentName
}
param publicKey string
param adminUsername string = 'azureuser'
// load abbreviations for resource names
var abbrs = loadJsonContent('./abbreviations.json')

var publicIPAddresses_vscode_ip_name = '${abbrs.networkPublicIPAddresses}${environmentName}-${vscodeDomainNameLabel}'
var publicIPAddresses_cluster_ip_name = '${abbrs.networkPublicIPAddresses}${environmentName}-${clusterDomainNameLabel}'
var nsg_vscode_name = '${abbrs.networkNetworkSecurityGroups}${environmentName}-${vscodeDomainNameLabel}'
var nsg_cluster_name = '${abbrs.networkNetworkSecurityGroups}${environmentName}-${clusterDomainNameLabel}'
var vnet_name = '${abbrs.networkVirtualNetworks}${environmentName}'
var vm_name = '${abbrs.computeVirtualMachines}${environmentName}'
var primary_nic_name = '${abbrs.networkNetworkInterfaces}${environmentName}-${vscodeDomainNameLabel}'
var secondary_nic_name = '${abbrs.networkNetworkInterfaces}${environmentName}-${clusterDomainNameLabel}'

resource pip_vscode_resource 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: publicIPAddresses_vscode_ip_name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: vscodeDomainNameLabel
    }
  }
  tags: tags
}

resource pip_cluster_resource 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: publicIPAddresses_cluster_ip_name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: clusterDomainNameLabel
    }
  }
  tags: tags
}

resource nsg_vscode_resource 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: nsg_vscode_name
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAnyHTTPSInbound'
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAnyHTTPInbound'
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource nsg_cluster_resource 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: nsg_cluster_name
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAnyHTTPSInbound'
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAnyHTTPInbound'
        type: 'Microsoft.Network/networkSecurityGroups/securityRules'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet_resource 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnet_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsg_vscode_resource.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'kind'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsg_cluster_resource.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource primary_nic_resource 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: primary_nic_name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: pip_vscode_resource.id
            properties: {
              deleteOption: 'Delete'
            }
          }
          subnet: {
            id: vnet_resource.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: true
    disableTcpStateTracking: false
    networkSecurityGroup: {
      id: nsg_vscode_resource.id
    }
  }
}

resource secondary_nic_resource 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: secondary_nic_name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig2'
        properties: {
          publicIPAddress: {
            id: pip_cluster_resource.id
            properties: {
              deleteOption: 'Delete'
            }
          }
          subnet: {
            id: vnet_resource.properties.subnets[1].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: true
    disableTcpStateTracking: false
    networkSecurityGroup: {
      id: nsg_vscode_resource.id
    }
  }
}

resource vm_resource 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vm_name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        name: '${vm_name}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: environmentName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              keyData: publicKey
              path: '/home/${adminUsername}/.ssh/authorized_keys'
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: primary_nic_resource.id
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
        {
          id: secondary_nic_resource.id
          properties: {
            primary: false
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource deploymentscript 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm_resource
  name: 'prepare-vm'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/jmservera/cka/main/kind/create.sh'
      ]
    }
    protectedSettings: {
      commandToExecute: 'TOKEN="${vscodeServerToken}" URL="${pip_vscode_resource.properties.dnsSettings.fqdn}" LOCAL_IP_ADDRESS="${primary_nic_resource.properties.ipConfigurations[0].properties.privateIPAddress}" SECONDARY_IP_ADDRESS="${secondary_nic_resource.properties.ipConfigurations[0].properties.privateIPAddress}" bash create.sh'
    }
  }
}
