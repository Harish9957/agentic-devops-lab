# Auth mirrors what `aws eks get-token` does manually — same mechanism, just invoked by the
# kubernetes provider's exec plugin instead of by hand. The Floci-specific endpoint override and
# fake credentials only apply when use_floci is true, same pattern as provider.tf's own AWS
# provider config.
locals {
  eks_auth_args = concat(
    ["eks", "get-token", "--cluster-name", aws_eks_cluster.app.name, "--region", var.aws_region],
    var.use_floci ? ["--endpoint-url", "http://localhost:4566"] : []
  )
  eks_auth_env = var.use_floci ? {
    AWS_ACCESS_KEY_ID     = "test"
    AWS_SECRET_ACCESS_KEY = "test"
  } : null
}

provider "kubernetes" {
  host                   = aws_eks_cluster.app.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.app.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.eks_auth_args
    env         = local.eks_auth_env
  }
}
