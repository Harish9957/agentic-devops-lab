# ALB is internet-facing infra — belongs in the public subnet, never alongside compute (same
# public-vs-private split 02-terraform-vpc established for its own NAT gateway).
#
# Spans both of 02-terraform-vpc's public subnets (2 AZs) — ALBs require at least 2 Availability
# Zones; Floci enforces this too (confirmed empirically when a single-subnet apply failed), not
# just real AWS. See 02-terraform-vpc's phase2-apply.md notes for how the second subnet got added.

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
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnet_ids

  tags = {
    Name = "${var.name}-alb"
    env  = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name_prefix = "tg-"
  port        = var.node_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "instance"
  # Registered by aws_autoscaling_attachment.app (eks.tf), attached to the EKS node group's own
  # managed ASG — not a hand-declared one.

  # Port changes force replacement — without create_before_destroy, Terraform tries to destroy the
  # old target group before the listener stops referencing it, which AWS rejects
  # (ResourceInUse: "in use by a listener or rule"). Create-then-rewire-then-destroy avoids that.
  lifecycle {
    create_before_destroy = true
  }

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
