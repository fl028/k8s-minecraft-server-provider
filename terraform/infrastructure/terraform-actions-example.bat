@echo off
echo "Script start."

echo "Setting env vars."
set TERRAFORM_PATH=.\example\example.exe
set TF_VAR_AZURE_CLIENT_ID=00000000-00000000-00000000-00000000
set TF_VAR_AZURE_CLIENT_SECRET=00000000-00000000-00000000-00000000
set TF_VAR_AZURE_TENANT_ID=00000000-00000000-00000000-00000000
set TF_VAR_AZURE_SUBSCRIPTION_ID=00000000-00000000-00000000-00000000
set TF_VAR_PROJECT_ROOT_PATH=C:\Users\example\example
set TF_VAR_SERVER_DOMAIN=mc-server-provider-example

echo "Init Terraform ..."
%TERRAFORM_PATH% init -upgrade

echo "Destroying existing infrastructure..."
%TERRAFORM_PATH% destroy -auto-approve

echo "Planning the new infrastructure..."
%TERRAFORM_PATH% plan

echo "Applying the changes..."
%TERRAFORM_PATH% apply -auto-approve

echo "Refreshing Terraform state..."
%TERRAFORM_PATH% refresh

echo "Script completed."

