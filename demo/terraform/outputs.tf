# Output the name of the namespace that was created/destroyed.
output "namespace" {
  value = trimspace(kubernetes_namespace.app_namespace.metadata[0].name)
}
