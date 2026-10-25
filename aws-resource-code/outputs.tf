# Values Terraform prints after apply.

output "vpc_id" {
  value = aws_vpc.main.id
}

output "web_server_public_ip" {
  value = aws_instance.web.public_ip
}

output "bucket_name" {
  value = aws_s3_bucket.files.bucket
}
