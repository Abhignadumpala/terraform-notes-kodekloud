# aws_s3_bucket_object (what the module note's source lesson uses) has been
# deprecated since AWS provider v4.0 - aws_s3_object is the current resource.

resource "aws_s3_object" "finance_2020" {
  bucket = aws_s3_bucket.finance.id
  key    = "finance-2020.txt"
  source = "${path.module}/finance-2020.txt"
}
