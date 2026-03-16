module "s3-bucket" {
  source      = "../modules/s3-bucket"
  kms_key_arn = module.kms.kms_key_arn
  bucket_name = var.bucket_name
}

module "kms" {
  source         = "../modules/kms"
  kms_alias_name = var.kms_alias_name
}

module "dynamoDB" {
  source              = "../modules/dynamoDB"
  dynamodb_table_name = var.dynamodb_table_name
}
