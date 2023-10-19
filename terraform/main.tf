provider "aws" {
  region = "us-east-2"
}

resource "aws_kms_key" "this" {
  description             = "kms using in university santo tomas project"
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/ecs/university-santo-tomas-app-python"
}

resource "aws_ecs_cluster" "this" {
  name = "university-santo-tomas-app-python"

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.this.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.this.name
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "example" {
  family                   = "app-python"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = "arn:aws:iam::636400435876:role/ecsTaskExecutionRole"

  container_definitions = templatefile("${path.module}/container_definitions.json",
    {
      account_id     = "636400435876"
      region         = "us-east-2"
      container_name = "university-santo-tomas-app-python"
      container_port = 5000
      ecr_name       = aws_ecr_repository.this.id
    }
  )

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_ecs_service" "this" {
  name            = "app-python"
  cluster         = aws_ecs_cluster.this.name
  task_definition = aws_ecs_task_definition.example.arn
  desired_count   = 1
  network_configuration {
    subnets          = ["subnet-018df030d18797eee", "subnet-04b983dec4193a880", "subnet-01d2c38a9a9a74958"]
    security_groups  = ["sg-0c73df152db741129"]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    base              = 1
    capacity_provider = "FARGATE"
    weight            = 100
  }

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }

  load_balancer {
   target_group_arn = element(concat(module.alb.target_group_arns, []), 0)
   container_name   = "university-santo-tomas-app-python"
   container_port   = 5000
 }
}

resource "aws_ecr_repository" "this" {
  name                 = "usantotomas-app-python"
  image_tag_mutability = "MUTABLE"
}


module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "usantotomas-application-lb"

  load_balancer_type = "application"

  vpc_id          = "vpc-047f6b1c67309dae6"
  subnets         = ["subnet-018df030d18797eee", "subnet-04b983dec4193a880", "subnet-01d2c38a9a9a74958"]
  security_groups = ["sg-0c73df152db741129"]


  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 5000
      target_type      = "ip"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 5000
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "Test"
  }
}

