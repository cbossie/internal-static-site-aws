data "aws_vpc_endpoint" "s3_endpoint" {
  id = var.s3_interface_endpoint_id
  service_name  = "com.amazonaws.${var.region}.s3"
}

data "aws_vpc" "proxy_vpc" {
    id= var.vpc_id
}

module "ecs_cluster" {
  source       = "terraform-aws-modules/ecs/aws"
  cluster_name = "${var.appid}-proxy"
}

resource "aws_s3_bucket" "spa_bucket" {
  bucket_prefix = var.appid
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
          awslogs-create-group  = "true"
          awslogs-group         = "${appid}-proxy-logs"
          awslogs-region        = var.region
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
  ingress = [{
    protocol    = -1
    description = "Ingress to proxy"
    from_port   = 0
    self        = true
    to_port     = 0
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
    self        = true
    to_port     = 0
    cidr_blocks = [local.cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}