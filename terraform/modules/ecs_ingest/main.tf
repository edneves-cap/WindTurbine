resource "aws_ecr_repository" "ingest" {
  name = "ingest"
}

resource "aws_ecs_cluster" "this" {
  name = "ingest-cluster"
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "ecsTaskExtraPolicy"
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:ListBucket"], Resource = [var.s3_bucket_arn, "${var.s3_bucket_arn}/*"] },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [var.db_secret_arn] },
      { Effect = "Allow", Action = ["rds-db:connect"], Resource = ["*"] }
    ]
  })
}

resource "aws_ecs_task_definition" "ingest" {
  family                   = "ingest-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      name      = "ingest"
      image     = "${aws_ecr_repository.ingest.repository_url}:latest"
      essential = true
      environment = [
        { name = "DB_CONN", value = var.db_conn_string }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/ingest"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/ecs/ingest"
  retention_in_days = 14
}

data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events_role" {
  name               = "events-run-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

resource "aws_iam_role_policy" "events_role_policy" {
  role = aws_iam_role.events_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["ecs:RunTask"], Resource = [aws_ecs_task_definition.ingest.arn] },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = [aws_iam_role.ecs_task_execution.arn] }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "s3_put" {
  name = "s3-unzipped-put-rule"
  event_pattern = jsonencode({
    source        = ["aws.s3"],
    "detail-type" = ["Object Created"],
    detail = {
      bucket = { name = [var.s3_bucket_name] }
      object = { key = [{ prefix = var.s3_prefix }] }
    }
  })
}

resource "aws_cloudwatch_event_target" "run_task" {
  rule     = aws_cloudwatch_event_rule.s3_put.name
  arn      = aws_ecs_cluster.this.arn
  role_arn = aws_iam_role.events_role.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.ingest.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = var.subnet_ids
      assign_public_ip = "ENABLED"
      security_groups  = var.security_group_ids
    }
  }
}

output "ecr_repo" {
  value = aws_ecr_repository.ingest.repository_url
}
