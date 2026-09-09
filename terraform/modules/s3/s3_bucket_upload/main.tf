resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name
  #acl = "private" # or can be "public-read"
  tags = {
    Name = var.bucket_name
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "object" {
  for_each = fileset("${path.root}/../data", "*")

  bucket = aws_s3_bucket.data.id
  key    = "raw/${each.value}"
  source = "${path.root}/../data/${each.value}"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag        = filemd5("${path.root}/../data/${each.value}")
  source_hash = filemd5("${path.root}/../data/${each.value}")
}

/*
resource "aws_s3_object" "object" {
  for_each = fileset("${path.root}/data/", "*")
  bucket = aws_s3_bucket.data.id
  key    = each.value
  source = "${path.root}/data/${each.value}"
  # etag makes the file update when it changes; see https://stackoverflow.com/questions/56107258/terraform-upload-file-to-s3-on-every-apply
  etag   = filemd5("${path.root}/data/${each.value}")
  #content_type = "text/csv"
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.data.id
  key    = "test_file"
  source = "${path.root}/../data/agua_zhum.zip"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("${path.root}/../data/agua_zhum.zip")
}

*/
#https://dev.to/ashraf-minhaj/send-local-files-to-s3-using-terraform-c17
