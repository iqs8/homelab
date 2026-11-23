output "bucket_name" { value = aws_s3_bucket.velero.id }
output "region" { value = var.region }
output "velero_user" { value = aws_iam_user.velero.name }