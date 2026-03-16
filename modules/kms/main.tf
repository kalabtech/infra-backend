resource "aws_kms_key" "this" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 20
  enable_key_rotation     = true
}

resource "aws_kms_alias" "this" {
  name          = var.kms_alias_name
  target_key_id = aws_kms_key.this.key_id
}
