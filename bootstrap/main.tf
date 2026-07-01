terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" { region = "us-east-1" }

# Tells AWS to trust tokens issued by GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# The role GitHub Actions will assume
resource "aws_iam_role" "gha" {
  name = "github-actions-terraform"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" },
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:25michaelthomas/aws-portfolio-api:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gha_admin" {
  role       = aws_iam_role.gha.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "role_arn"        { value = aws_iam_role.gha.arn }
output "oidc_provider"   { value = aws_iam_openid_connect_provider.github.arn }

resource "aws_ecr_repository" "api" {
  name                 = "portfolio-api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
output "ecr_url" { value = aws_ecr_repository.api.repository_url }