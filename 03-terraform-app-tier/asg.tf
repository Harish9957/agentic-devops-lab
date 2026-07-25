# Compute goes in the private subnet, never the public one — design rule inherited from
# 02-terraform-vpc, see spec/phases/phase0-preflight.md.

resource "aws_security_group" "ec2" {
  name_prefix = "${var.name}-ec2-"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  # Only the ALB can reach the instances, on the app port — not a wide-open CIDR.
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ec2"
    env  = var.environment
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ec2.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-ec2"
      env  = var.environment
    }
  }

  tags = {
    Name = "${var.name}-app-lt"
    env  = var.environment
  }
}

resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.name}-app-"
  vpc_zone_identifier = [data.terraform_remote_state.vpc.outputs.private_subnet_id]
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ec2"
    propagate_at_launch = true
  }

  tag {
    key                 = "env"
    value               = var.environment
    propagate_at_launch = true
  }
}
