# Compute goes in the private subnet, never the public one — design rule inherited from
# 02-terraform-vpc, see spec/phases/phase0-preflight.md. nginx runs as a Kubernetes Pod on this
# cluster's node group, not a bare EC2 instance — see phase3 notes for why this replaced the
# earlier EC2/ASG/user_data approach (Floci actually runs a real k3s server for "EKS", with none of
# the user_data/data-plane gaps the EC2 path had).

resource "aws_iam_role" "eks_cluster" {
  name = "${var.name}-eks-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node" {
  name = "${var.name}-eks-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_cluster" "app" {
  name     = "${var.name}-eks"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = concat(
      data.terraform_remote_state.vpc.outputs.public_subnet_ids,
      [data.terraform_remote_state.vpc.outputs.private_subnet_id],
    )
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.app.name
  node_group_name = "${var.name}-node"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [data.terraform_remote_state.vpc.outputs.private_subnet_id]
  instance_types  = [var.instance_type]

  scaling_config {
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
    desired_size = var.node_group_desired_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
}

# Only the ALB can reach worker nodes, on the NodePort nginx's Service listens on — not a
# wide-open CIDR. EKS's own cluster security group (auto-created via vpc_config) is what the
# node group's instances actually use.
#
# KNOWN GAP: Floci's EKS emulation doesn't return a real cluster_security_group_id — comes back as
# an empty string, not a valid security group ID (confirmed via `terraform console`), because its
# "cluster" is just a bare k3s container, not real VPC-level security-group-backed infra. count
# skips this resource when that's blank so Floci applies don't fail, but real AWS always populates
# it, so this rule still applies there.
resource "aws_security_group_rule" "nodeport_from_alb" {
  count = aws_eks_cluster.app.vpc_config[0].cluster_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = var.node_port
  to_port                  = var.node_port
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.app.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

# Registers the node group's own (EKS-managed) ASG into the ALB's target group — same mechanism
# a hand-rolled ASG would use, just attached to the ASG EKS creates for us rather than one we
# declare ourselves.
#
# KNOWN GAP: on Floci, aws_eks_node_group.app.resources[0].autoscaling_groups[0].name reports a
# name, but no real Auto Scaling group actually exists behind it — confirmed empirically, this
# attachment fails with "Auto Scaling group ... not found" against Floci's Auto Scaling API. Real
# EKS managed node groups do create a genuine backing ASG, so this is skipped for the Floci path
# only (var.use_floci) rather than something wrong with the pattern itself.
resource "aws_autoscaling_attachment" "app" {
  count = var.use_floci ? 0 : 1

  autoscaling_group_name = aws_eks_node_group.app.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.app.arn
}
