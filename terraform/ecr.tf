# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
resource "aws_ecr_repository" "repository" {
  name = var.service_name

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository#force_delete
  force_delete = true
}
