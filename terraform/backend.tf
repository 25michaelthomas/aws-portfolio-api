terraform {
  backend "s3" {
    bucket       = "8696-tfstate-portfolio"
    key          = "app/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}