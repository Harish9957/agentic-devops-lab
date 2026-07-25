# ALB is internet-facing infra — belongs in the public subnet, never alongside compute (same
# public-vs-private split 02-terraform-vpc established for its own NAT gateway).
#
# KNOWN GAP: 02-terraform-vpc currently exposes only ONE public subnet (single AZ, us-east-1a).
# Real AWS requires an ALB's subnets to span at least two distinct Availability Zones — creation
# will fail against real AWS with only one. This plans/applies fine against Floci (which doesn't
# enforce the constraint), so that's the only target this phase is verified against. Called out
# explicitly rather than silently working around it — see spec.md and phase2 notes.

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-alb"
    env  = var.environment
  }
}

resource "aws_lb" "app" {
  name_prefix        = "app-"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [data.terraform_remote_state.vpc.outputs.public_subnet_id]

  tags = {
    Name = "${var.name}-alb"
    env  = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name_prefix = "tg-"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.name}-tg"
    env  = var.environment
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
