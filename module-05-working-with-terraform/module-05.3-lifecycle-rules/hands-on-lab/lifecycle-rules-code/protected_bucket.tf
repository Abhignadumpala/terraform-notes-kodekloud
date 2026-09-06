# Demonstrates prevent_destroy. Bucket name needs to be globally unique,
# hence random_id - same pattern as the state-locking-lab bootstrap config.
#
# To actually test this: try `terraform destroy` (or a change that would
# force replacement, like renaming the bucket) and confirm Terraform refuses.
# To actually clean it up afterward: remove the `lifecycle` block below (or
# just delete this file), run `terraform apply` to update the resource in
# state, then `terraform destroy` will be able to remove it.

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "protected" {
  bucket = "lifecycle-rules-lab-${random_id.bucket_suffix.hex}"

  lifecycle {
    prevent_destroy = true
  }
}
