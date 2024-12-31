# Domain join method : ADDS
# Image - Azure Market place
# Get existing host pool data
data "azurerm_virtual_desktop_host_pool" "existing" {
    name                = "your-hostpool-name"
    resource_group_name = "your-resource-group-name"
}

# Create network interface for the VM
resource "azurerm_network_interface" "sessionhost_nic" {
    name                = "sessionhost-nic"
    location            = "your-location"
    resource_group_name = "your-resource-group-name"

    ip_configuration {
        name                          = "internal"
        subnet_id                     = "your-subnet-id"
        private_ip_address_allocation = "Dynamic"
    }
}

# Create the session host VM
resource "azurerm_windows_virtual_machine" "sessionhost" {
    name                = "avd-sessionhost"
    resource_group_name = "your-resource-group-name"
    location            = "your-location"
    size                = "Standard_D2s_v3"
    admin_username      = "adminuser"
    admin_password      = "your-password"
    network_interface_ids = [
        azurerm_network_interface.sessionhost_nic.id
    ]

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsDesktop"
        offer     = "Windows-10"
        sku       = "20h2-evd"
        version   = "latest"
    }
}

# Join the VM to the host pool
resource "azurerm_virtual_machine_extension" "join_domain" {
    name                 = "join-domain"
    virtual_machine_id   = azurerm_windows_virtual_machine.sessionhost.id
    publisher            = "Microsoft.Compute"
    type                 = "JsonADDomainExtension"
    type_handler_version = "1.3"

    settings = jsonencode({
        Name = "your-domain-name"
        User = "your-domain-join-username"
        Restart = "true"
        Options = "3"
    })

    protected_settings = jsonencode({
        Password = "your-domain-join-password"
    })
}

resource "azurerm_virtual_machine_extension" "AVD_agent" {
    name                 = "AVD-agent"
    virtual_machine_id   = azurerm_windows_virtual_machine.sessionhost.id
    publisher            = "Microsoft.PowerShell"
    type                 = "DSC"
    type_handler_version = "2.73"

    settings = <<SETTINGS
        {
                "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_3-10-2021.zip",
                "configurationFunction": "Configuration.ps1\\AddSessionHost",
                "properties": {
                        "hostPoolName": "${data.azurerm_virtual_desktop_host_pool.existing.name}",
                        "registrationInfoToken": "${data.azurerm_virtual_desktop_host_pool.existing.registration_info[0].token}"
                }
        }
SETTINGS
}
