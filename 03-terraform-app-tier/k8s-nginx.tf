# nginx as a Kubernetes Pod on the EKS cluster (eks.tf), fronted by a NodePort Service the ALB's
# target group forwards to (var.node_port — see alb.tf), scaled by an HPA using the cluster's
# built-in metrics-server (bundled by default, confirmed working against Floci's k3s-backed EKS).

resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name   = "nginx"
    labels = { app = "nginx" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = { app = "nginx" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:stable"

          port {
            container_port = 80
          }

          resources {
            requests = { cpu = "50m" }
            limits   = { cpu = "200m" }
          }
        }
      }
    }
  }

  depends_on = [aws_eks_node_group.app]
}

resource "kubernetes_service_v1" "nginx" {
  metadata {
    name = "nginx"
  }

  spec {
    type     = "NodePort"
    selector = { app = "nginx" }

    port {
      port        = 80
      target_port = 80
      node_port   = var.node_port
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "nginx" {
  metadata {
    name = "nginx"
  }

  spec {
    min_replicas = 1
    max_replicas = 4

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.nginx.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}
