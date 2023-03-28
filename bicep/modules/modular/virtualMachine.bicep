// File: virtualMachine.bicep
// Author: Bunny Davies
//
// !Work in progress!
// TODO: Add Linux support
// TODO: Add logic for enableHotpatching
// 
// Change log:
// - Initial release
// - Added example usage
//
// Deploys a Virtual Machine
// - OS disk has naming convention disk-os-vmname
// - Each data disk has naming convention disk-disknumber-vmname
// 
// @secure()
// param localAdminPassWeb_p string

// var envSettings_v = {
//   dev: {
//     storageType: 'StandardSSD_LRS'
//     vmSize: 'Standard_B2s'
//   }
//   qa: {
//     storageType: 'StandardSSD_LRS'
//     vmSize: 'Standard_B2s'
//   }
//   prod: {
//     storageType: 'StandardSSD_LRS'
//     vmSize: 'Standard_B2ms'
//   }
// }

// module vm_m 'modules/modular/virtualMachine.bicep' = {
//   scope: group_r
//   name: 'vm_m'
//   params: {
//     adminPass_p: localAdminPassWeb_p
//     azureAdLogin_p: true
//     dataDisks_p: [
//       {
//         sizeGb: 50
//         type: 'StandardSSD_LRS'
//       }
//     ]
//     location_p: location_p
//     nicId_p: nic_m.outputs.id
//     resourceTags_p: resourceTags_v
//     storageAccountType_p: envSettings_v[envShort_v].storageType
//     vmName_p: vmName_v
//     vmSize_p: envSettings_v[envShort_v].vmSize
//   }
// }

// global params
param location_p string = resourceGroup().location
param resourceTags_p object = {}

// account params
@description('''
Must be between 8-123 characters long and must satisfy at least 3 of password complexity requirements from the following:
- Contains an uppercase character
- Contains a lowercase character
- Contains a numeric digit
- Contains a special character
- Control characters are not allowed
''')
@minLength(8)
@maxLength(123)
@secure()
param adminPass_p string

@description('''
Specifies the name of the administrator account. This property cannot be updated after the VM is created.
**Windows-only restriction**: Cannot end in "."
**Disallowed values**: "administrator", "admin", "user", "user1", "test", "user2", "test1", "user3", "admin1", "1", "123", "a", "actuser", "adm", "admin2", "aspnet", "backup", "console", "david", "guest", "john", "owner", "root", "server", "sql", "support", "support_388945a0", "sys", "test2", "test3", "user4", "user5".
**Minimum-length (Linux)**: 1 character
**Max-length (Linux)**: 64 characters
**Max-length (Windows)**: 20 characters.
''')
param adminUser_p string = 'localadmin'

// disk params

// build data disks array
@description('''
Array of data disks.
```
{
  sizeGB: 50
  type: 'Standard_LRS'
}
```
''')
param dataDisks_p array = []

var dataDisksArray_v = [for (disk, i) in dataDisks_p: {
  lun: i
  createOption: 'Empty'
  deleteOption: diskDeleteOption_p
  diskSizeGB: disk.sizeGb
  name: 'disk-${i}-${vmName_p}'
  managedDisk: {
    storageAccountType: disk.type
  }
}]

@allowed([
  'Attach'
  'Empty'
  'FromImage'
])
@description('''
Specifies how the virtual machine should be created.
- **Attach**: This value is used when you are using a specialized disk to create the virtual machine.
- **FromImage**: This value is used when you are using an image to create the virtual machine. If you are using a platform image, you also use the imageReference element described above. If you are using a marketplace image, you also use the plan element previously described.
''')
param diskCreateOption_p string = 'FromImage'

@allowed([
  'Delete'
  'Detach'
])
@description('Specify what happens to the disk when the VM is deleted.')
param diskDeleteOption_p string = 'Detach'

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'PremiumV2_LRS'
  'Standard_LRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'UltraSSD_LRS'
])
@description('Specifies the storage account type for the managed disk. NOTE: UltraSSD_LRS can only be used with data disks, it cannot be used with OS Disk..')
param storageAccountType_p string = 'Standard_LRS'

// network params
@allowed([
  'Delete'
  'Detach'
])
@description('Specify what happens to the network interface when the VM is deleted.')
param nicDeleteOption_p string = 'Detach'

@description('Network interface resource ID.')
param nicId_p string

// os params
@description('''
Indicates whether Automatic Updates is enabled for the Windows virtual machine. Default value is true.
For virtual machine scale sets, this property can be updated and updates will take effect on OS reprovisioning.
''')
param automaticUpdates_p bool = true

@description('The image SKU.')
param imageSku_p string = '2019-datacenter-gensecond'

@description('''
Indicates whether virtual machine agent should be provisioned on the virtual machine.
When this property is not specified in the request body, default behavior is to set it to true.
This will ensure that VM Agent is installed on the VM so that extensions can be added to the VM later.
''')
param provisionVmAgent_p bool = true

@description('''
Enables customers to patch their Azure VMs without requiring a reboot.
For enableHotpatching, `provisionVmAgent_p` must be set to `true` and `patchMode_p` must be set to `AutomaticByPlatform`.
''')
param hotpatching_p bool = false

@allowed([
  'AutomaticByOS'
  'AutomaticByPlatform'
  'Manual'
])
@description('''
Specifies the mode of VM Guest Patching to IaaS virtual machine or virtual machines associated to virtual machine scale set with OrchestrationMode as Flexible.
- **AutomaticByOS** - The virtual machine will automatically be updated by the OS. The property WindowsConfiguration.enableAutomaticUpdates must be true.
- **AutomaticByPlatform** - the virtual machine will automatically updated by the platform. The properties provisionVMAgent and WindowsConfiguration.enableAutomaticUpdates must be true
- **Manual** - You control the application of patches to a virtual machine. You do this by applying patches manually inside the VM. In this mode, automatic updates are disabled; the property WindowsConfiguration.enableAutomaticUpdates must be false
''')
param patchMode_p string = 'AutomaticByOS'

@description('Specifies the time zone of the virtual machine')
param timeZone_p string = 'GMT Standard Time'

// resource params
@description('Install the Azure AD Login extension')
param azureAdLogin_p bool = false

@description('''
Specifies the host OS name of the virtual machine. This name cannot be updated after the VM is created.
**Max-length (Windows)**: 15 characters
**Max-length (Linux)**: 64 characters.
Windows computer name cannot be:
- more than 15 characters long
- be entirely numeric
- or contain the following characters: ` ~ ! @ # $ % ^ & * ( ) = + _ [ ] { } \\ | ; : . ' \" , < > / ?.'
''')
param computerName_p string = vmName_p

@allowed([
  'None'
  'SystemAssigned,UserAssigned'
  'SystemAssigned'
  'UserAssigned'
])
param identity_p string = 'SystemAssigned'

@description('Name of the virtal machine. Try to follow requirements for computerName_p so that the computer and VM names align.')
param vmName_p string = 'vm${uniqueString(resourceGroup().id)}'

@description('Specifies the size of the virtual machine. Too many to prescribe using `@allowed` decorator.')
param vmSize_p string = 'Standard_B1s'

// resources
resource vm_r 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName_p
  location: location_p
  tags: resourceTags_p
  identity: {
    type: identity_p ?? null
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize_p
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    // rewrite to support multiple or create dedicated module for assigning additional interfaces
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId_p
          properties: {
            deleteOption: nicDeleteOption_p
          }
        }
      ]
    }
    osProfile: {
      adminPassword: adminPass_p
      adminUsername: adminUser_p
      computerName: computerName_p
      windowsConfiguration: {
        enableAutomaticUpdates: automaticUpdates_p
        provisionVMAgent: provisionVmAgent_p
        patchSettings: {
          enableHotpatching: hotpatching_p
          patchMode: patchMode_p
        }
        timeZone: timeZone_p
      }
    }
    storageProfile: {
      dataDisks: dataDisksArray_v
      osDisk: {
        createOption: diskCreateOption_p
        deleteOption: diskDeleteOption_p
        managedDisk: {
          storageAccountType: storageAccountType_p
        }
        name: 'disk-os-${vmName_p}'
      }
      imageReference: {
        offer: 'WindowsServer'
        publisher: 'MicrosoftWindowsServer'
        sku: imageSku_p
        version: 'latest'
      }
    }
  }

  resource aadExtension_r 'extensions' = if (azureAdLogin_p) {
    name: 'AADLoginForWindows'
    location: location_p
    properties: {
      autoUpgradeMinorVersion: true
      publisher: 'Microsoft.Azure.ActiveDirectory'
      type: 'AADLoginForWindows'
      typeHandlerVersion: '1.0'
    }
  }
}

// outputs
output api string = vm_r.apiVersion
output id string = vm_r.id
output name string = vm_r.name
output type string = vm_r.name
