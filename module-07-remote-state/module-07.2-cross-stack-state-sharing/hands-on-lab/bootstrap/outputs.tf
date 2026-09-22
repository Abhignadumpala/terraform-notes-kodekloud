output "state_bucket_name" {
  description = "Shared S3 bucket both network/ and compute/ point their backend block at"
  value       = aws_s3_bucket.state.id
}
