provider "aws" {
  region = "us-east-1"
}

resource "aws_ecs_cluster" "this" {
  name = "strapi-backend-cluster-ecs"
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
       { name = "NODE_ENV", value = "production" },
       { name = "HOST", value = "0.0.0.0" },
       { name = "PORT", value = "1337" },
       { name = "DATABASE_CLIENT", value = "sqlite" },
       { name = "DATABASE_FILENAME", value = "./data/data.db" },
       { name = "APP_KEYS", value = var.app_keys },
       { name = "ADMIN_JWT_SECRET", value = var.admin_jwt_secret },
       { name = "API_TOKEN_SALT", value = var.api_token_salt },
       { name = "TRANSFER_TOKEN_SALT", value = var.transfer_token_salt },
       { name = "ENCRYPTION_KEY", value = var.encryption_key },
       { name = "JWT_SECRET", value = var.jwt_secret }
     ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/strapi-backend-ecs"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
         }
       }
    }
  ])
}

resource "aws_ecs_service" "strapi" {
  name            = "strapi-backend-service-ecs"
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
