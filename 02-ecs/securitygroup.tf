# Visitors can reach the ALB over HTTP. In production add ACM + HTTPS.
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Allow HTTP from the internet to the Morays ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Demo HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "ALB to backend tasks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-alb-sg" }
}

# Fargate task can receive HTTP only from the ALB SG, not from the internet.
resource "aws_security_group" "tasks" {
  name_prefix = "${var.project_name}-task-"
  description = "Only ALB can reach the Apache container"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    description = "ECR image pull and AWS logs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-tasks-sg" }
}