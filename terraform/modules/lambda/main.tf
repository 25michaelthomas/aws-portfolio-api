variable "project" {}
variable "uploads_bucket" {}
variable "uploads_arn" {}
variable "processed_bucket" {}
variable "processed_arn" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda" {
  name = "${var.project}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "lambda_s3" {
  role = aws_iam_role.lambda.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = "s3:GetObject", Resource = "${var.uploads_arn}/*" },
      { Effect = "Allow", Action = "s3:PutObject", Resource = "${var.processed_arn}/*" }
    ]
  })
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.project}-s3-processor"
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  role             = aws_iam_role.lambda.arn
  timeout          = 60
  memory_size      = 256
  environment { variables = { PROCESSED_BUCKET = var.processed_bucket } }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.uploads_arn
}

resource "aws_s3_bucket_notification" "upload" {
  bucket = var.uploads_bucket
  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

output "function_name" { value = aws_lambda_function.processor.function_name }