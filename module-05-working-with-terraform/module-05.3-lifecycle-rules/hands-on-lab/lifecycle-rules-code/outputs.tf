output "instance_id" {
  value = aws_instance.web.id
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "instance_ami" {
  value = aws_instance.web.ami
}

output "protected_bucket_name" {
  value = aws_s3_bucket.protected.id
}
