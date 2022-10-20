output "project_name" {
  value = var.project_name
}

output "service_name" {
  value = var.service_name
}

output "region" {
  value = var.region
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository#repository_url
output "ecr_repository_url" {
  value = aws_ecr_repository.repository.repository_url
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity#account_id
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}