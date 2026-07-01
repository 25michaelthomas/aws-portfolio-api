##############################################
# modules/compute/main.tf
# EC2 launch template + Auto Scaling Group + ALB + IAM
##############################################

variable "project" {}
variable "vpc_id" {}
variable "subnet_ids" {}
variable "app_sg_id" {}
variable "alb_sg_id" {}
variable "instance_type" {}
variable "image_uri" {} # full ECR image URI:tag
variable "region" {}
variable "db_secret_arn" {}
variable "db_host" {}
variable "uploads_bucket" {}
variable "uploads_arn" {}

##############################################
# IAM role the EC2 instances run as
##############################################

resource "aws_iam_role" "app" {
  name = "${var.project}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Pull images from ECR
resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Use Session Manager instead of SSH
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read the DB secret and use the uploads bucket
resource "aws_iam_role_policy" "app_extra" {
  role = aws_iam_role.app.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        Resource = var.db_secret_arn
      },
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject", "s3:GetObject"],
        Resource = "${var.uploads_arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.app.name
}

##############################################
# Latest Amazon Linux 2023 AMI (ARM64)
##############################################

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64"
}

##############################################
# Launch template: what each instance does at boot
##############################################

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-app-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf install -y docker
    systemctl enable --now docker
    aws ecr get-login-password --region ${var.region} \
      | docker login --username AWS --password-stdin ${split("/", var.image_uri)[0]}
    docker run -d --restart unless-stopped -p 80:8000 \
      -e DB_SECRET_ARN=${var.db_secret_arn} -e DB_HOST=${var.db_host} \
      -e UPLOAD_BUCKET=${var.uploads_bucket} -e AWS_REGION=${var.region} \
      ${var.image_uri}
  EOF
  )
}

##############################################
# Application Load Balancer
##############################################

resource "aws_lb" "app" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

##############################################
# Auto Scaling Group
##############################################

resource "aws_autoscaling_group" "app" {
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-app"
    propagate_at_launch = true
  }
}

##############################################
# Outputs
##############################################

output "alb_dns" {
  value = aws_lb.app.dns_name
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "tg_arn_suffix" {
  value = aws_lb_target_group.app.arn_suffix
}
