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
      name  = "spa_proxy"
      image = "nginxinc/nginx-s3-gateway:latest"
      environment = [
        {
          name  = "S3_BUCKET_NAME"
          value = "${aws_s3_bucket.spa_bucket.id}"
        },
        {
          name  = "PROVIDE_INDEX_PAGE"
          value = "true"
        },
        {
          name  = "S3_REGION"
          value = var.region
        },
        {
          name  = "S3_STYLE"
          value = "default"
        },
        {
          name  = "S3_SERVER_PORT"
          value = "443"
        },

        {
          name  = "S3_SERVER_PROTO"
          value = "https"
        },
        {
          name  = "AWS_SIGS_VERSION"
          value = "4"
        },
        {
          name  = "S3_DEBUG"
          value = "true"
        },
        {
          name  = "ALLOW_DIRECTORY_LIST"
          value = "false"
        },
        {
          name  = "S3_SERVER"
          value = replace(aws_vpc_endpoint.s3_endpoint.dns_entry[0].dns_name, "*", "bucket")
        },





      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "nginx-logs"
          awslogs-region        = var.region
          awslogs-stream-prefix = "s3"
        }
      }

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
  desired_count        = 1
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
    path     = "/index.html"
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

resource "aws_lb_listener" "proxy_listener_https" {
  load_balancer_arn = aws_lb.proxy_lb.arn
  port              = 443
  protocol          = "HTTPS"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }
  certificate_arn = aws_acm_certificate.lb_cert.arn

}

resource "aws_acm_certificate" "lb_cert" {
  private_key      = file("cert/sample-private-key.pem")
  certificate_body = file("cert/sample-certificate.pem")
}

resource "aws_route53_zone" "privatezone" {
  name = "samplesite.local"
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

resource "aws_route53_record" "alb_record" {
  zone_id = aws_route53_zone.privatezone.zone_id
  name    = "www"
  type    = "A"
  alias {
    name                   = aws_lb.proxy_lb.dns_name
    zone_id                = aws_lb.proxy_lb.zone_id
    evaluate_target_health = true
  }
}

