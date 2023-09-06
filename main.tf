variable "rg_name" {}
variable "rg_location" {}
variable "db_username" {}
variable "db_password" {}
variable "flask_username" {}
variable "flask_password" {}

#Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.rg_location
}

#Creating ssh key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
############################################################################
#virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "myTFVnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.rg_location
  resource_group_name = var.rg_name
  depends_on = [ azurerm_resource_group.rg ]
}

#subnet web
resource "azurerm_subnet" "web-subnet"{
  name 				  = "web-subnet"
  resource_group_name = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.0.1.0/24"]
  depends_on = [ azurerm_resource_group.rg ]
}

#subnet db 
resource "azurerm_subnet" "db-subnet" {
  name = "db-subnet"
  resource_group_name = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.0.2.0/24"]
  depends_on = [ azurerm_resource_group.rg ]
}
############################################################################
#network security group for web subnet
resource "azurerm_network_security_group" "web_nsg" {
  name = "web_nsg"
  resource_group_name = var.rg_name
  location = var.rg_location
  depends_on = [ azurerm_resource_group.rg ]
  

  security_rule {
    name ="AllowHTTP"
  	priority = 100
  	direction = "Inbound"
	  access = "Allow"
  	protocol = "Tcp"
  	source_port_range = "*"
  	destination_port_range = "8080"
  	source_address_prefix = "*"
  	destination_address_prefix = "*"
  }

  security_rule {
    name ="AllowSSH"
	  priority = 110
	  direction = "Inbound"
	  access = "Allow"
	  protocol = "Tcp"
	  source_port_range = "*"
	  destination_port_range = "22"
	  source_address_prefix = "*"
	  destination_address_prefix = "*"
  }
}

#network security group for db subnet
resource "azurerm_network_security_group" "db_nsg" {
  name = "db_nsg"
  resource_group_name = var.rg_name
  location            = var.rg_location
  depends_on = [ azurerm_resource_group.rg ]

  security_rule {
    name ="AllowSSH"
  	priority = 100
  	direction = "Inbound"
  	access = "Allow"
  	protocol = "*"
  	source_port_range = "*"
  	destination_port_range = "22"
  	source_address_prefix = "*"
   	destination_address_prefix = "*"
  }
    security_rule {
    name ="AllowAppAccess"
  	priority = 110
  	direction = "Inbound"
  	access = "Allow"
  	protocol = "*"
  	source_port_range = "*"
  	destination_port_range = "5432"
  	source_address_prefix = "*"
  	destination_address_prefix = "*"
  }
}
############################################################################
# Create an Azure public IP address for the Flask VM
resource "azurerm_public_ip" "flask" {
  name                = "flask-ip"
  location            = var.rg_location
  resource_group_name = var.rg_name
  allocation_method   = "Dynamic"
  depends_on = [ azurerm_resource_group.rg ]
}
# Create the Flask VM
resource "azurerm_linux_virtual_machine" "flask" {
  name                = "flask-vm"
  resource_group_name = var.rg_name
  location            = var.rg_location
  size                = "Standard_B1s"
  admin_username      = var.flask_username
  admin_password      = var.flask_password  
  network_interface_ids = [azurerm_network_interface.flask.id]
  depends_on = [ azurerm_resource_group.rg ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_ssh_key {
        username = var.flask_username
        public_key = file("C:\\Users\\idan\\.ssh\\id_rsa.pub")
        #tls_private_key.example_ssh.public_key_openssh 
    }
    connection {
      type = "ssh"
      user = var.flask_username
      password = var.flask_password
      host = azurerm_linux_virtual_machine.flask.public_ip_address
      private_key = file("C:\\Users\\idan\\.ssh\\id_rsa")
      
    }
    provisioner "remote-exec" {
      inline = [ 
      "mkdir kfir" ,
      "sudo apt-get update -y && sudo apt-get upgrade -y",
      "sudo apt-get install -y python3.10", 
      "sudo apt-get install -y python3-pip",
      "pip3 install flask",
      ]
    }
  }

# Create a network interface for the Flask VM
resource "azurerm_network_interface" "flask" {
  name                = "flask-nic"
  location            = var.rg_location
  resource_group_name = var.rg_name
  depends_on = [ azurerm_resource_group.rg ]

  ip_configuration {
    name                          = "flask-ip-config"
    subnet_id                     = azurerm_subnet.web-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id           = azurerm_public_ip.flask.id
  }
}

resource "azurerm_managed_disk" "flask-md" {
  name                 = "flask-md"
  location             = var.rg_location
  resource_group_name  = var.rg_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
  depends_on = [ azurerm_resource_group.rg ]
}


resource "azurerm_virtual_machine_data_disk_attachment" "flask-attach" {
  managed_disk_id    = azurerm_managed_disk.flask-md.id
  virtual_machine_id = azurerm_linux_virtual_machine.flask.id
  lun                ="10"
  caching            = "ReadWrite"
}
############################################################################
# Create an Azure public IP address for the PostrgreSQL VM
resource "azurerm_public_ip" "PostgreSQL" {
  name                = "PostgreSQLPostgreSQL-ip"
  location            = var.rg_location
  resource_group_name = var.rg_name
  allocation_method   = "Dynamic"
  depends_on = [ azurerm_resource_group.rg ]
}

# Create the PostgreSQL VM 
resource "azurerm_linux_virtual_machine" "PostgreSQL" {
  name                = "PostgreSQL-vm"
  resource_group_name = var.rg_name
  location            = var.rg_location
  size                = "Standard_B1s"
  admin_username      = var.db_username
  admin_password      = var.db_password  
  network_interface_ids = [azurerm_network_interface.PostgreSQL.id]
  depends_on = [ azurerm_resource_group.rg ]
  

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
    admin_ssh_key {
        username = var.db_username
        public_key = file("C:\\Users\\idan\\.ssh\\id_rsa.pub")
        #tls_private_key.example_ssh.public_key_openssh 
    }
      connection {
      type = "ssh"
      user = var.flask_username
      password = var.flask_password
      host = azurerm_linux_virtual_machine.flask.public_ip_address
      private_key = file("C:\\Users\\idan\\.ssh\\id_rsa")
      
    }
    provisioner "file" {
      source = "C:\\Users\\Idan\\לימודים סלע\\terraform_project"
      destination = "/tmp/psql_script.sh"
    }

    provisioner "remote-exec" {
      inline = [ 
        "chmod +x /tmp/psql_script.sh",
        "/tmp/psql_script.sh"
      ]
    }
}
    # Create a network interface for the PostgreSQL VM
resource "azurerm_network_interface" "PostgreSQL" {
  name                = "PostgreSQL-nic"
  location            = var.rg_location
  resource_group_name = var.rg_name
  depends_on = [ azurerm_resource_group.rg ]

  ip_configuration {
    name                          = "PostgreSQL-ip-config"
    subnet_id                     = azurerm_subnet.web-subnet.id
    private_ip_address_allocation = "Dynamic"
	  public_ip_address_id           = azurerm_public_ip.PostgreSQL.id
  }

}

resource "azurerm_managed_disk" "PostgreSQL-md" {
  name                 = "PostgreSQL-md"
  location             = var.rg_location
  resource_group_name  = var.rg_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
  depends_on = [ azurerm_resource_group.rg ]
}


resource "azurerm_virtual_machine_data_disk_attachment" "PostgreSQL-attach" {
  managed_disk_id    = azurerm_managed_disk.PostgreSQL-md.id
  virtual_machine_id = azurerm_linux_virtual_machine.PostgreSQL.id
  lun                ="10"
  caching            = "ReadWrite"
}
