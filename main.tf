provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "newvpc" {
 cidr_block = "10.0.0.0/16"

 tags = {
   Name = "nuvve_test"
 }
}

resource "aws_subnet" "public_subnets" {
 count             = length(var.public_subnet_cidrs)
 vpc_id            = aws_vpc.newvpc.id
 cidr_block        = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)

 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}

resource "aws_subnet" "private_subnets" {
 count             = length(var.private_subnet_cidrs)
 vpc_id            = aws_vpc.newvpc.id
 cidr_block        = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)

 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}


resource "aws_ecs_cluster" "grafana_cluster" {
  name = "grafana-cluster"
}


#*************************SECURITY GROUPS***************************

#SG ECS
resource "aws_security_group" "ecs_service_security_group" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.newvpc.id
}

resource "aws_security_group_rule" "outbound_ecs" {
  security_group_id = aws_security_group.ecs_service_security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "inbound_ecs" {
  security_group_id = aws_security_group.ecs_service_security_group.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

#SG ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  vpc_id      = aws_vpc.newvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

#***********************GRAFANA TASK DEFINITION*****************************

resource "aws_ecs_task_definition" "grafana_task_definition" {
  family                    = "grafana"
  container_definitions     = jsonencode([
    {
      name      = "grafana"
      image = var.image
      aws_region = var.aws_region
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        },
      ]
    },
  ])
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  memory                    = var.ecs_memory
  cpu                       = var.ecs_cpu
}
#*******************************GET SUBNET IDS***********************

data "aws_subnet_ids" "private_subnets_list" {
  vpc_id = aws_vpc.newvpc.id

  tags = {
    Tier = "Private"
  }
}

data "aws_subnet_ids" "public_subnets_list" {
  vpc_id = aws_vpc.newvpc.id

  tags = {
    Tier = "Public"
  }
}

#********************************** CREATE THE ECS SERVICE*********************

resource "aws_ecs_service" "ecs_service" {
  name                                = "grafana-deployment"
  cluster                             = aws_ecs_cluster.grafana_cluster.id
  task_definition                     = aws_ecs_task_definition.grafana_task_definition.arn
  desired_count                       = 1
  launch_type                         = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "grafana-1"
    container_port   = 3000
  }

  network_configuration {
    #possible failure
    subnets             = data.aws_subnet_ids.private_subnets_list.ids
    security_groups     = [aws_security_group.ecs_service_security_group.id]
    assign_public_ip    = true
  }

  depends_on            = [aws_lb_target_group.target_group]
}

resource "aws_lb_target_group" "target_group" {
  name                  = "grafana"
  port                  = 3000
  protocol              = "HTTP"
  target_type           = "ip"
  vpc_id                = aws_vpc.newvpc.id
}

# ******************************ALB LB ***********************************************
resource "aws_lb" "ecs_alb" {
  name                              = "grafana-alb"
  internal                          = false
  load_balancer_type                = "application"
  security_groups                   = [aws_security_group.alb_sg.id]
  subnets                           = data.aws_subnet_ids.public_subnets_list.ids
  enable_cross_zone_load_balancing  = true
  enable_http2                      = true
}

#******************************* LISTENERS *************************************

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


#***********************MYSQL RDS******************

resource "aws_db_instance" "mysql_db" {
  allocated_storage    = 10
  db_name              = "mysql_db"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "root"
  #not using secrets just to speed up this exercise
  password             = "1234567891011"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}
