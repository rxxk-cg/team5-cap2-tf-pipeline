terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

locals {

  ecs_service_name  = "team5-ecs-svc-${var.run_string}"
  ecs_task_name = "team5-ecs-task-${var.run_string}"
  ecs_clus_name = "team5-ecs-clus-tf-${var.run_string}"
  ecs_task_exec_role = "team5-ecs-clus-tf-${var.run_string}"
  ecs_load_bal = "team5-ecs-load-bal-${var.run_string}"
  ecs_load_bal_sg = "team5-load-bal-sg-${var.run_string}"
  ecs_target_group = "team5-target-group-${var.run_string}"
  ecs_clus_service_sg = "team5-clus-svc-sg-${var.run_string}"
  image_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com/${var.ecr_repo}:${var.latest-Tag}"
}


# Configure the AWS Provider
provider "aws" {
    region = var.primary_region
    access_key = var.access_key 
    secret_key = var.secret_key
}

data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "my_cluster" {
  name = local.ecs_clus_name # Naming the cluster
}

resource "aws_ecs_task_definition" "my_first_task" {
  family                   = local.ecs_task_name # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${local.ecs_task_name}",
      "image": "${local.image_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = local.ecs_task_exec_role
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_ecs_service" "team5-my_first_service" {
  name            = local.ecs_service_name                        # Naming our first service
  cluster         = "${aws_ecs_cluster.my_cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.my_first_task.arn}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Setting the number of containers we want deployed to 3
  
  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.my_first_task.family}"
    container_port   = 3000 # Specifying the container port
  }

  network_configuration {
    #subnets          = ["${data.aws_subnet.priv-a.id}", "${data.aws_subnet.priv-b.id}", "${data.aws_subnet.priv-c.id}"]
    subnets          = var.input_private_subnetid
    assign_public_ip = false # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Setting the security group
  }
}


resource "aws_alb" "application_load_balancer" {
  name               = local.ecs_load_bal # Naming our load balancer
  load_balancer_type = "application"
  subnets = var.input_pub_subnetid
  # Referencing the security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  name = local.ecs_load_bal_sg
  vpc_id = "${data.aws_vpc.selected.id}"
  ingress {
    from_port   = 80 # Allowing traffic in from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = local.ecs_target_group
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${data.aws_vpc.selected.id}" # Referencing the default VPC
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our tagrte group
  }
}

resource "aws_security_group" "service_security_group" {
  name = local.ecs_clus_service_sg
  vpc_id = "${data.aws_vpc.selected.id}"
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

terraform {

  backend "s3" {
      bucket = "team5-capstone2-tf-state"
      key    = "team5-state"
      region = "us-west-2"
  }
}