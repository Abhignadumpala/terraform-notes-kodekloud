# Instance profile name — the EC2 module needs this
# depends_on: EC2 must wait until the SSM policy is attached too (hidden link)

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.nginx_profile.name
  depends_on  = [aws_iam_role_policy_attachment.ssm]
}