provider "aws" {
  region = "us-east-1"
}
resource "aws_db_subnet_group" "strapi" {
  name       = "strapi-db-subnet"
  subnet_ids = ["subnet-019f80fcdf181c8d7", "subnet-0fa63b900995738f6"]
}
resource "aws_db_instance" "strapi" {
  identifier           = "strapi-db"
  engine               = "postgres"
  engine_version       = "11.22"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.strapi.name
  publicly_accessible  = true
  skip_final_snapshot  = true
}

resource "aws_cloudwatch_log_group" "strapi" {
  name              = "/ecs/strapi-backend"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "this" {
  name = "strapi-backend-cluster"
}

resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-backend-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.existing_execution_role_arn

  container_definitions = jsonencode([
    {
      name         = "strapi-backend"
      image        = "${var.ecr_repo}:${var.image_tag}"
      essential    = true
      portMappings = [{ containerPort = 1337 }]
      environment = [
        { name = "HOST", value = "0.0.0.0" },
        { name = "PORT", value = "1337" },
        { name = "APP_KEYS", value = var.app_keys },
        { name = "API_TOKEN_SALT", value = var.api_token_salt },
        { name = "ADMIN_JWT_SECRET", value = var.admin_jwt_secret },
        { name = "TRANSFER_TOKEN_SALT", value = var.transfer_token_salt },
        { name = "ENCRYPTION_KEY", value = var.encryption_key },
        { name = "JWT_SECRET", value = var.jwt_secret },
        { name = "DATABASE_CLIENT", value = "postgres" },
        { name = "DATABASE_HOST", value = aws_db_instance.strapi.address },
        { name = "DATABASE_PORT", value = "5432" },
        { name = "DATABASE_NAME", value = var.db_username }, 
        { name = "DATABASE_USERNAME", value = var.db_username },
        { name = "DATABASE_PASSWORD", value = var.db_password },
        { name = "DATABASE_SSL", value = "false" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.strapi.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "strapi" {
  name            = "strapi-backend-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-019f80fcdf181c8d7", "subnet-0fa63b900995738f6"]
    security_groups  = ["sg-009961e820fd3b943"]
    assign_public_ip = true
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "strapi-rds-sg"
  vpc_id = "vpc-04642e7bb88eda30e"
}

resource "aws_security_group_rule" "ecs_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = "sg-009961e820fd3b943"
}
