data "aws_vpc_endpoint" "s3_endpoint" {
  id           = var.s3_interface_endpoint_id
  service_name = "com.amazonaws.${var.region}.s3"
}

data "aws_vpc" "proxy_vpc" {
  id = var.vpc_id
}

resource "aws_ecr_repository" "proxy_repo" {
  name = "${var.appid}-proxy-repo"
}

module "ecs_cluster" {
  source       = "terraform-aws-modules/ecs/aws"
  cluster_name = "${var.appid}-proxy"
}

resource "aws_s3_bucket" "spa_bucket" {
  bucket_prefix = var.appid
}

resource "aws_s3_bucket_policy" "vpce_policy" {
  bucket = aws_s3_bucket.spa_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "VPCEPOLICY"


    Statement = [
      {
        Sid       = "Access-to-specific-VPCE-only"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = [aws_s3_bucket.spa_bucket.arn, "${aws_s3_bucket.spa_bucket.arn}/*"]
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = "${var.s3_interface_endpoint_id}"
          }
        }
      }
    ]
  })
}


# The role for the ECS execution
resource "aws_iam_role" "task_execution_role" {
  name = "${var.appid}_execution_role"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "task"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "ecstasks"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_role" "task_role" {
  name = "${var.appid}_proxy_role"
  managed_policy_arns = [
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
        Sid    = "ecs"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "ecs"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}



#Task Definition
resource "aws_ecs_task_definition" "proxy_task" {
  family                   = "proxy"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  container_definitions = jsonencode([
    {
      name  = "${var.appid}_spa_proxy"
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
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group = "true"
          awslogs-group        = "${appid}-proxy-logs"
          awslogs-region       = var.region
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


#Security group for the proxy. The proxy can receive traffic from the LB
resource "aws_security_group" "proxy_sg" {
  name_prefix = "${var.appid}-proxy"
  vpc_id      = var.vpc_id

  ingress = [
 {
    protocol        = -1
    description     = "Ingress to proxy"
    from_port       = 0
    self = true
    security_groups = [aws_security_group.lb_sg.id]
    to_port         = 0
  }]
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "lb_sg" {
  name_prefix = "${var.appid}-lb"
  vpc_id      = var.vpc_id
  ingress {
    protocol    = -1
    description = "Ingress to LB"
    from_port   = 0
    to_port     = 0
    cidr_blocks = data.aws_vpc.proxy_vpc.cidr_block_associations[*].cidr_block
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "proxy_lb" {
  name_prefix        = "proxy"
  internal           = true
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.lb_sg.id
  ]
  subnets = var.subnets
}


# Optional HTTP Listener
resource "aws_lb_listener" "proxy_listener_http" {
  load_balancer_arn = aws_lb.proxy_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }
  count = var.allow_http ? 1 : 0
}

# HTTPS listener
resource "aws_lb_listener" "proxy_listener_https" {
  load_balancer_arn = aws_lb.proxy_lb.arn
  port              = 443
  protocol          = "HTTPS"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }
  certificate_arn = var.certificate_arn

}

#Target Group
resource "aws_lb_target_group" "proxy" {
  name        = "proxy"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/index.html"
    protocol = "HTTP"
    interval = 60
  }
}

resource "aws_route53_record" "alb_record" {
  zone_id = var.private_zone_id
  name    = "www"
  type    = "A"
  alias {
    name                   = aws_lb.proxy_lb.dns_name
    zone_id                = aws_lb.proxy_lb.zone_id
    evaluate_target_health = true
  }
}