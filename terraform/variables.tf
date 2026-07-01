variable "region"        { default = "us-east-1" }
variable "project"       { default = "portfolio" }
variable "instance_type" { default = "t4g.micro" }
variable "db_instance"   { default = "db.t4g.micro" }
variable "image_tag"     { default = "latest" }   # CI overrides this with the Git SHA
variable "alert_email"   { description = "Email for CloudWatch alarms" }