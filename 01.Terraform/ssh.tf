# https://www.educative.io/answers/how-to-create-an-ssh-key-in-terraform
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "public_key" {
  value     = tls_private_key.ssh_key.public_key_openssh
}


# resource "azapi_resource" "pubkey" {
#   type      = "Microsoft.Compute/sshPublicKeys@2024-07-01"
#   name      = "terraform_ex_pubkey"
#   location  = azurerm_resource_group.rg.location
#   parent_id = azurerm_resource_group.rg.id
# }

# resource "azapi_resource_action" "pubkey_gen" {
#   type        = "Microsoft.Compute/sshPublicKeys@2024-07-01"
#   resource_id = azapi_resource.pubkey.id
#   action      = "generateKeyPair"
#   method      = "POST"

#   response_export_values = ["publicKey", "privateKey"]
# }

# output "publicKey" {
#   value = azapi_resource_action.pubkey_gen.output.publicKey
# }
