resource "aws_s3_bucket" "velero" {
  bucket = "${lower(local.cluster_name)}-bucket"
  acl    = "private"
  force_destroy = true
}
