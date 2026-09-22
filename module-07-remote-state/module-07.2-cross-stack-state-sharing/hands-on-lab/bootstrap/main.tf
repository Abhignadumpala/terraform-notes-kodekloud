# One shared backend bucket for both the network and compute stacks - real
# teams put many stacks' state files under different keys in one bucket,
# not a separate bucket per stack.

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket        = "tf-remote-state-lab-${random_id.suffix.hex}"
  force_destroy = true # true only for this lab, so it can clean itself up - never in a real team bucket

  lifecycle {
    prevent_destroy = false # true in a real team bucket - false here so the lab can clean itself up
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
