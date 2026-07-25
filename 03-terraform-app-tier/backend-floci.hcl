bucket         = "agentic-devops-lab-tfstate"
key            = "03-terraform-app-tier/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "agentic-devops-lab-tflocks"
encrypt        = true

# Floci-specific overrides — backend blocks can't reference variables, so these are duplicated here
# rather than reused from provider.tf's use_floci toggle.
access_key                  = "test"
secret_key                  = "test"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
use_path_style              = true
endpoints = {
  s3       = "http://localhost:4566"
  dynamodb = "http://localhost:4566"
}
