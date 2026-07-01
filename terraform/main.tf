data "aws_caller_identity" "current" {}

locals {
  ecr_url   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/portfolio-api"
  image_uri = "${local.ecr_url}:${var.image_tag}"
}

module "network" {
  source  = "./modules/network"
  project = var.project
}

module "database" {
  source         = "./modules/database"
  project        = var.project
  subnet_ids     = module.network.subnet_ids
  sg_id          = module.network.rds_sg_id
  instance_class = var.db_instance
}

module "storage" {
  source  = "./modules/storage"
  project = var.project
}

module "compute" {
  source         = "./modules/compute"
  project        = var.project
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.subnet_ids
  app_sg_id      = module.network.app_sg_id
  alb_sg_id      = module.network.alb_sg_id
  instance_type  = var.instance_type
  image_uri      = local.image_uri
  region         = var.region
  db_secret_arn  = module.database.db_secret_arn
  db_host        = module.database.db_host
  uploads_bucket = module.storage.uploads_bucket
  uploads_arn    = module.storage.uploads_arn
}

module "lambda" {
  source           = "./modules/lambda"
  project          = var.project
  uploads_bucket   = module.storage.uploads_bucket
  uploads_arn      = module.storage.uploads_arn
  processed_bucket = module.storage.processed_bucket
  processed_arn    = module.storage.processed_arn
}

module "monitoring" {
  source        = "./modules/monitoring"
  project       = var.project
  alert_email   = var.alert_email
  asg_name      = module.compute.asg_name
  db_identifier = "${var.project}-db"
  lambda_name   = module.lambda.function_name
}