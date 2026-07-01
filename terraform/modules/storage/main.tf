variable "project" {}
resource "random_id" "suffix" { byte_length = 4 }

resource "aws_s3_bucket" "uploads" {
  bucket        = "${var.project}-uploads-${random_id.suffix.hex}"
  force_destroy = true
}
resource "aws_s3_bucket" "processed" {
  bucket        = "${var.project}-processed-${random_id.suffix.hex}"
  force_destroy = true
}

output "uploads_bucket"   { value = aws_s3_bucket.uploads.id }
output "uploads_arn"      { value = aws_s3_bucket.uploads.arn }
output "processed_bucket" { value = aws_s3_bucket.processed.id }
output "processed_arn"    { value = aws_s3_bucket.processed.arn }