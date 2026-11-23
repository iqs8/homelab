resource "aws_iam_user" "velero" {
  name = "velero"
}

data "aws_iam_policy_document" "velero" {
  # Read/write/delete files inside the bucket
  statement {
    sid = "ObjectsInBackupBucket"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.velero.arn}/*"]
  }
  # List what's in the bucket, and ask which region it's in
  statement {
    sid       = "TheBucketItself"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.velero.arn]
  }
}

resource "aws_iam_user_policy" "velero" {
  name   = "velero-backup-bucket"
  user   = aws_iam_user.velero.name
  policy = data.aws_iam_policy_document.velero.json
}