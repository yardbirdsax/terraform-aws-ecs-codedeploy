locals {
  deployment_name = var.deployment_name == "" ? "nginx-test" : var.deployment_name
}