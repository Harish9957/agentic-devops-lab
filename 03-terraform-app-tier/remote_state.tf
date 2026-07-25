# Reads 02-terraform-vpc's outputs (vpc_id, private_subnet_id, public_subnet_id) so this use case
# never hardcodes IDs — see spec/spec.md rule 5. Config here mirrors backend-floci.hcl /
# backend-aws.hcl.example, but as a data source (not a backend block) it's allowed to reference
# variables directly.
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket                      = "agentic-devops-lab-tfstate"
    key                         = "02-terraform-vpc/terraform.tfstate"
    region                      = var.aws_region
    access_key                  = var.use_floci ? "test" : null
    secret_key                  = var.use_floci ? "test" : null
    skip_credentials_validation = var.use_floci ? true : null
    skip_metadata_api_check     = var.use_floci ? true : null
    skip_requesting_account_id  = var.use_floci ? true : null
    use_path_style              = var.use_floci ? true : null
    endpoints                   = var.use_floci ? { s3 = "http://localhost:4566" } : null
  }
}
