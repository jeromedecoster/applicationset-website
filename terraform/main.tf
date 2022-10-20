locals {
  # https://www.terraform.io/language/expressions/references#filesystem-and-workspace-info
  # target the $PROJECT_DIR
  project_dir = abspath("${path.root}/..")
}

resource "null_resource" "env-file" {

  triggers = {
    everytime = uuid()
  }

  provisioner "local-exec" {
    command = "scripts/env-file.sh .env AWS_ACCOUNT_ID REPOSITORY_URL"

    working_dir = local.project_dir

    environment = {
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      REPOSITORY_URL = aws_ecr_repository.repository.repository_url
    }
  }
}
