data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "rds:*",
      "rds-db:*",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.aws_s3_bucket_arn,
      "arn:aws:s3:::agri-csv-raw-data-edneves/*",
      "arn:aws:logs:*:*:*",
      "arn:aws:rds:*",
      var.db_secret_arn,
      "*"
    ]
  }
  /* statement {
      effect = "Allow"
      actions = [
        "lambda:Invoke"
      ]
      resources = [
        resource.aws_lambda_function.example.arn
      ]
    } 
    # check execution role permissions to run EC2
    # Error: The provided execution role does not have permissions to call CreateNetworkInterface on EC2*/
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "lambda_policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "${path.module}/code"
  output_path = "${path.module}/lambda/function.zip"
}

data "archive_file" "python_layer" {
  type        = "zip"
  source_dir  = "${path.module}/python"
  output_path = "${path.module}/lambda/python-layer.zip"
}

data "archive_file" "gdal_layer" {
  type        = "zip"
  source_dir  = "${path.module}/gdal-layer"
  output_path = "${path.module}/lambda/gdal-layer.zip"
}

resource "aws_lambda_layer_version" "python" {
  layer_name          = "${var.lambda_function_name}-python"
  description         = "Python dependencies for the ingestion Lambda"
  compatible_runtimes = ["python3.11"]
  filename            = data.archive_file.python_layer.output_path
  source_code_hash    = data.archive_file.python_layer.output_base64sha256
}

resource "aws_lambda_layer_version" "gdal" {
  layer_name          = "${var.lambda_function_name}-gdal"
  description         = "GDAL native binaries built for AWS Lambda Python 3.11"
  compatible_runtimes = ["python3.11"]
  filename            = data.archive_file.gdal_layer.output_path
  source_code_hash    = data.archive_file.gdal_layer.output_base64sha256
}

resource "aws_lambda_function" "example" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.example.arn
  handler          = "unzip.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  timeout          = 900
  memory_size      = 4096

  layers = [
    aws_lambda_layer_version.python.arn,
    aws_lambda_layer_version.gdal.arn,
  ]

  environment {
    variables = {
      PATH            = "/opt/bin:/usr/local/bin:/usr/bin:/bin"
      LD_LIBRARY_PATH = "/opt/lib:/usr/local/lib:/usr/lib"
      GDAL_DATA       = "/opt/share/gdal"
      PROJ_LIB        = "/opt/share/proj"
      OUTPUT_PREFIX   = "unzipped/"
    }
  }

  vpc_config {
    subnet_ids         = var.aws_db_subnet_group_id
    security_group_ids = [var.aws_security_group_id]
  }

  tags = {
    Environment = "production"
    Application = "lambda_function"
  }
}


resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.aws_s3_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.example.arn
    events = [
      "s3:ObjectCreated:*",

    ]
  }
}

# Grant permission to TRIGGER
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.aws_s3_bucket_arn
}


