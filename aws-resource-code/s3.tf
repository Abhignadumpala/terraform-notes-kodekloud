# S3 bucket: storage for files (objects).
# Bucket names must be unique, so I use bucket_prefix and AWS adds a random ending.

resource "aws_s3_bucket" "files" {
  bucket_prefix = "mr-cloud-files-"

  tags = {
    Name = "Mr_cloud_files"
  }
}

# Versioning: keeps old versions of a file when I overwrite or delete it.

resource "aws_s3_bucket_versioning" "files" {
  bucket = aws_s3_bucket.files.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access, so nothing in the bucket is ever public by mistake.

resource "aws_s3_bucket_public_access_block" "files" {
  bucket                  = aws_s3_bucket.files.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
