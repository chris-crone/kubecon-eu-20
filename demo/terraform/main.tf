# Use the Kubernetes backend for Terraform state so that state is preserved
# between actions.
terraform {
    backend "kubernetes" {}
}

# As we're doing operations on Kubernetes objects, we need the kubernetes
# provider.
provider "kubernetes" {
  config_context = var.context

  version = "~> 1.11"
}

# The namespace resource that we will use to install our application into.
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
  }
}
