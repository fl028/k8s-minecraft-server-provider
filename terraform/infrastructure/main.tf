resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Create virtual network
resource "azurerm_virtual_network" "terraform_network" {
  name                = "Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "terraform_subnet" {
  name                 = "Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "PublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  domain_name_label =  var.SERVER_DOMAIN
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraform_nsg" {
  name                = "NetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
  name                       = "API-HTTP"
  priority                   = 1002
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "30000"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

  security_rule {
  name                       = "MC-SERVER"
  priority                   = 1003
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "30001-30010"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

}

# Associate public IP with network interface of virtual machine
resource "azurerm_network_interface" "terraform_nic" {
  name                = "NIC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nic_configuration1"
    subnet_id                     = azurerm_subnet.terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Generate random text for unique storage account name
resource "random_id" "random_id" {
  keepers = {
    resource_group = azurerm_resource_group.rg.name
  }
  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage_account" {
  name                    = "diag${random_id.random_id.hex}"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  account_tier            = "Standard"
  account_replication_type = "LRS"
}

# creating cloud init script
data "template_cloudinit_config" "vm" {
  gzip          = true
  base64_encode = true

 part {
    content_type = "text/cloud-config"
    content = <<EOF
    package_update: true
    package_upgrade: true
    packages:
      - python3
      - python3-pip
      - python3-venv
      - docker.io
      - git
    EOF
  }

  part {
  content_type = "text/cloud-config"
  content = <<EOF
    runcmd:
      - date +"%T.%N"
      - echo "Start cloud init"
      - mkdir /tmp/workspace
      - cd /tmp/workspace
      - date +"%T.%N"
      - echo "Clone repo"
      - git clone https://github.com/fl028/k8s-minecraft-server-provider.git
      - date +"%T.%N"
      - echo "Start k3s installation"
      - cd
      - ufw disable
      - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode=644
      - date +"%T.%N"
      - echo "Sleeping - k3s installation"
      - sleep 60
      - date +"%T.%N"
      - echo "Cube config"
      - mkdir /root/.kube
      - cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
      - export KUBECONFIG=/root/.kube/config
      - date +"%T.%N"
      - echo "Helm setup"
      - mkdir /tmp/workspace/helm-download
      - curl -fsSL -o /tmp/workspace/helm-download/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
      - chmod 700 /tmp/workspace/helm-download/get_helm.sh
      - /tmp/workspace/helm-download/get_helm.sh
      - sleep 10
      - date +"%T.%N"
      - echo "docker setup"
      - docker run -d -p 5000:5000 --restart=always --name registry registry:2
      - echo "Verify"
      - sleep 6
      - date +"%T.%N"
      - docker ps
      - echo
      - kubectl cluster-info
      - echo
      - kubectl get pods,services -A -o wide
      - date +"%T.%N"
      - echo "minecraft data prep"
      - mkdir /tmp/workspace/minecraft-data
      - echo "operator prep"
      - cd /tmp/workspace/k8s-minecraft-server-provider/operator-sdk/smooth-mc-operator
      - curl -LO https://github.com/operator-framework/operator-sdk/releases/download/v1.31.0/operator-sdk_linux_amd64
      - chmod +x operator-sdk_linux_amd64 && sudo mv operator-sdk_linux_amd64 /usr/local/bin/operator-sdk
      - make docker-build IMG=localhost:5000/smooth-mc-operator-chart
      - make docker-build docker-push IMG=localhost:5000/smooth-mc-operator-chart
      - make deploy IMG=localhost:5000/smooth-mc-operator-chart
      - echo "Verify"
      - sleep 10
      - date +"%T.%N"
      - kubectl get pods -A -o wide
      - echo
      - echo "API prep"
      - cd /tmp/workspace/k8s-minecraft-server-provider/python/api
      - cp /root/.kube/config /tmp/workspace/k8s-minecraft-server-provider/python/api/config
      - docker build -t localhost:5000/mc-provider-api-container .
      - sleep 5
      - docker push localhost:5000/mc-provider-api-container
      - sleep 5
      - helm install mc-provider-api /tmp/workspace/k8s-minecraft-server-provider/helm/mc-provider-api
      - echo "Verify"
      - sleep 10
      - date +"%T.%N"
      - kubectl get pods -A -o wide
      - date +"%T.%N"
      - echo "Done"
    EOF
  }
}

# Create virtual machine (Standard B4ms (4 vcpus, 16 GiB memory))
resource "azurerm_linux_virtual_machine" "terraform_vm" {
  name                   = "vm1"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  network_interface_ids  = [azurerm_network_interface.terraform_nic.id] 
  size                   = "Standard_B4ms"          

  custom_data = data.template_cloudinit_config.vm.rendered 

  computer_name  = "vm1"
  admin_username = var.username

  os_disk {
    name                 = "osdisk1"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.username
    public_key = jsondecode(azapi_resource_action.ssh_public_key_gen.output).publicKey
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_account.primary_blob_endpoint  # Use the storage account for the first VM
  }
}

# Output variables to display the SSH command and IP
output "ssh_command_vm1"{
  value = "ssh -i ./private_key.pem azureadmin@${azurerm_public_ip.public_ip.ip_address}"
}

resource "local_file" "vscode_ssh_config" {
  filename = "vscode_ssh_config"
  content = <<-EOF
    Host vm1
        HostName ${azurerm_public_ip.public_ip.ip_address}
        User azureadmin
        IdentityFile ${var.PROJECT_ROOT_PATH}\terraform\infrastructure\${var.private_key_filename}
  EOF
}
