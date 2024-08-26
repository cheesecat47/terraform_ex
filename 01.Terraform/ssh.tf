# https://learn.microsoft.com/ko-kr/azure/virtual-machines/linux/quick-create-terraform?tabs=azure-cli
resource "azapi_resource" "pubkey" {
  type      = "Microsoft.Compute/sshPublicKeys@2024-07-01"
  name      = "terraform_ex_pubkey"
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
}

resource "azapi_resource_action" "pubkey_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2024-07-01"
  resource_id = azapi_resource.pubkey.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

resource "local_file" "privateKey" {
  content         = azapi_resource_action.pubkey_gen.output.privateKey
  filename        = "${path.module}/private.key"
  file_permission = "0400"
}

resource "local_file" "publicKey" {
  content         = azapi_resource_action.pubkey_gen.output.publicKey
  filename        = "${path.module}/public.key"
  file_permission = "0400"
}
