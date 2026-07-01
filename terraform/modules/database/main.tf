variable "project" {}
variable "subnet_ids" {}
variable "sg_id" {}
variable "instance_class" {}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "main" {
  identifier                  = "${var.project}-db"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = var.instance_class
  allocated_storage           = 20
  storage_type                = "gp3"
  db_name                     = "portfolio"
  username                    = "appadmin"
  manage_master_user_password = true       # AWS creates + rotates the password
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [var.sg_id]
  publicly_accessible         = false
  skip_final_snapshot         = true
}

output "db_host"        { value = aws_db_instance.main.address }
output "db_secret_arn"  { value = aws_db_instance.main.master_user_secret[0].secret_arn }