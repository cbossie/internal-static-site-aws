resource "aws_ecr_repository" "proxy_repo" {
  name = "spa-proxy"
}

module "ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  cluster_name = "ecs-spa-proxy"
}



# Task Definition
resource "aws_ecs_task_definition" "proxy_task" {
  family                   = "proxy"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  task_role_arn            = aws_iam_role.ecs_proxy_role.arn
  execution_role_arn       = aws_iam_role.ecs_proxy_role.arn
  container_definitions = jsonencode([
    {
      name      = "spa_proxy"
      image     = "${aws_ecr_repository.proxy_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "HTTP"
        }
      ]
    }
  ])
}


# Role
resource "aws_iam_role" "ecs_proxy_role" {
  name = "spa_proxy_role"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]
  inline_policy {
    name = "s3-policy"
    policy = jsonencode({

      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:GetObject"]
          Effect   = "Allow"
          Resource = [aws_s3_bucket.spa_bucket.arn, "${aws_s3_bucket.spa_bucket.arn}/*"]
        }
      ]
    })
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "task"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
      {
        Sid    = "ecs"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AssumeRo"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}



resource "aws_ecs_service" "proxy_service" {
  launch_type          = "FARGATE"
  name                 = "proxy-service"
  cluster              = module.ecs.cluster_id
  task_definition      = aws_ecs_task_definition.proxy_task.arn
  desired_count        = 4
  force_new_deployment = true
  network_configuration {
    security_groups  = [aws_security_group.all_vpc_sg.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.proxy.arn
    container_name   = "spa_proxy"
    container_port   = 80
  }

}







resource "aws_lb" "proxy_lb" {
  name_prefix        = "proxy"
  internal           = true
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.all_vpc_sg.id
  ]
  subnets = module.vpc.private_subnets
}

resource "aws_lb_target_group" "proxy" {
  name        = "proxy"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
    interval = 60
  }

}

resource "aws_lb_listener" "proxy_listener" {
  load_balancer_arn = aws_lb.proxy_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }
}

