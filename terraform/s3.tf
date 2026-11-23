resource "aws_s3_bucket" "velero" {
  bucket = var.bucket_name

  # Refuse to delete this bucket even on `terraform destroy`. Backups are the point.
  lifecycle {
    prevent_destroy = true
  }
}

# Block every way of making the bucket or its objects public
resource "aws_s3_bucket_public_access_block" "velero" {
  bucket                  = aws_s3_bucket.velero.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt everything at rest with S3-managed keys (SSE-S3, free)
resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Keep old versions of overwritten/deleted objects (undo for accidents)
resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration {
    status = "Enabled"
  }
}

# The SAFE cleanup rules only. Nothing here touches current objects by age.
resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    id     = "cleanup-leftovers"
    status = "Enabled"
    filter {} # whole bucket

    # Old versions (left behind when Kopia deletes/replaces a pack) go after 7 days
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    # Once those old versions are gone, remove the empty "delete marker" too
    expiration {
      expired_object_delete_marker = true
    }
    # Half-finished big uploads (e.g. a backup cut off mid-way) go after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.velero]
}

# Refuse any request that isn't over HTTPS
data "aws_iam_policy_document" "bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.velero.arn, "${aws_s3_bucket.velero.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "velero" {
  bucket     = aws_s3_bucket.velero.id
  policy     = data.aws_iam_policy_document.bucket.json
  depends_on = [aws_s3_bucket_public_access_block.velero]
}