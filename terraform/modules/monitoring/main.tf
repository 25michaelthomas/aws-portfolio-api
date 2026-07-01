variable "project" {}
variable "alert_email" {}
variable "asg_name" {}
variable "db_identifier" {}
variable "lambda_name" {}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project}/app"
  retention_in_days = 14
}

resource "aws_sns_topic" "alerts" { name = "${var.project}-alerts" }
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.project}-ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { AutoScalingGroupName = var.asg_name }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { FunctionName = var.lambda_name }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = { title = "EC2 CPU", metrics = [["AWS/EC2","CPUUtilization","AutoScalingGroupName",var.asg_name]], region = "us-east-1" } },
      { type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = { title = "Lambda Invocations", metrics = [["AWS/Lambda","Invocations","FunctionName",var.lambda_name]], region = "us-east-1" } }
    ]
  })
}