# Compute goes in the private subnet, never the public one — design rule inherited from
# 02-terraform-vpc, see spec/phases/phase0-preflight.md.

resource "aws_security_group" "ec2" {
  name_prefix = "${var.name}-ec2-"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  # No ingress yet — nothing needs to reach this instance directly until the ALB (later phase)
  # gets its own security group and this one is opened up to just that.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ec2"
  }
}

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = data.terraform_remote_state.vpc.outputs.private_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  tags = {
    Name = "${var.name}-ec2"
  }
}
