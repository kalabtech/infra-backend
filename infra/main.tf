module "s3-bucket" {
  source      = "../modules/s3-bucket"
  bucket_name = var.bucket_name
}

module "kms" {
  source         = "../modules/kms"
  kms_alias_name = var.kms_alias_name
}
