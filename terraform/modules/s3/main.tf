resource "aws_s3_bucket" "b1" {
    bucket = var.bucket_name
    #acl = "private" # or can be "public-read"
    tags = {
        Name = var.bucket_name
    }
}

resource "aws_s3_bucket_versioning" "b1" {
    bucket = aws_s3_bucket.b1.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_object" "object" {
    bucket = aws_s3_bucket.b1.id
    key = var.csv_s3_file_name
    #acl = "private" # or can be "public-read"
    source = "${path.root}/data/${var.csv_source_file_name}"
    etag = filemd5("${path.root}/data/${var.csv_source_file_name}")
    content_type = "text/csv"

    #depends_on = [ var.lambda_function ]
}

resource "aws_s3_bucket" "b2" {
  bucket = "versioning_example"
  
}

resource "aws_s3_bucket_versioning" "b2" {
    bucket = aws_s3_bucket.b2.id
    versioning_configuration {
        status = "Enabled"
    }
}  