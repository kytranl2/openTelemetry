# Create an ECS cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Action"    : "sts:AssumeRole",
      "Effect"    : "Allow",
      "Principal" : {
        "Service" : "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecs_demo_service" {
  name              = "/ecs/demo-service"
  retention_in_days = 7  # Set this to your desired retention period
}

# Attach necessary policies to the role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add this policy attachment in your Terraform configuration
resource "aws_iam_role_policy_attachment" "ecr_public_read_only" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# IAM Policy for ECR Access
data "aws_iam_policy_document" "ecr_access" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:ListImages"
    ]
    resources = ["*"]
  }
}

# Create a custom IAM policy
resource "aws_iam_policy" "ecs_task_execution_role_extra_policy" {
  name   = "ecs-task-execution-extra-policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_access_policy" {
  name   = "ECS-ECR-Access-Policy"
  policy = data.aws_iam_policy_document.ecr_access.json
}

resource "aws_iam_role_policy_attachment" "ecr_access_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}

# Attach the custom policy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_extra_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_role_extra_policy.arn
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_service" {
  name        = "ecs_service_sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for EFS
resource "aws_security_group" "efs_sg" {
  name        = "efs_sg"
  description = "Allow ECS tasks to access EFS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id, "sg-0f99a66990d032818"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EFS File System for OpenTelemetry Collector Config
resource "aws_efs_file_system" "otel_config_fs" {
  lifecycle_policy {
    transition_to_ia = "AFTER_14_DAYS"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "otel_config_mt" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.otel_config_fs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]
}

# EFS Access Point
resource "aws_efs_access_point" "otel_config_ap" {
  file_system_id = aws_efs_file_system.otel_config_fs.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/otel-config"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }
}
# Task Definition with OpenTelemetry Sidecar
resource "aws_ecs_task_definition" "task" {
  family                   = "demo-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      "name": "demo-app",
      "image": "851725314367.dkr.ecr.us-east-1.amazonaws.com/telemetry-springboot:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "OTEL_EXPORTER_OTLP_ENDPOINT",
          "value": "http://localhost:4317"
        }
      ],
      "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
            "awslogs-group": "/ecs/demo-service",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "demo-app"
            }
        }
    },
    {
      "name": "otel-collector",
      "image": "public.ecr.aws/aws-observability/aws-otel-collector",  # Updated to use the default image
      "portMappings": [
        {
          "containerPort": 4317,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "command": [
        "--config=/etc/otel-collector-config/otel-collector-config.yaml"
      ],
      "mountPoints": [
        {
          "sourceVolume": "otel-config",
          "containerPath": "/etc/otel-collector-config",
          "readOnly": true
        }
      ],
      "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/demo-service",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "otel-collector"
      }
    }
    }
  ])

  volume {
    name = "otel-config"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.otel_config_fs.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.otel_config_ap.id
      }
    }
  }
}


# ECS Service
resource "aws_ecs_service" "service" {
  name            = "demo-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [
      aws_security_group.ecs_service.id,
      aws_security_group.efs_sg.id
    ]
    assign_public_ip = true
  }
}
