# Output the public IP address of the PostgreSQL VM
output "PostgreSQL_vm_public_ip" {
  value = azurerm_linux_virtual_machine.PostgreSQL.public_ip_address
}

# Output the public IP address of the Flask VM
output "flask_vm_public_ip" {
  value = azurerm_linux_virtual_machine.flask.public_ip_address
}
