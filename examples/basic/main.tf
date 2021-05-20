terraform {
  required_version = ">=0.12.31"
  required_providers {
    aws = {
      version   = ">=3"
      source    = "hashicorp/aws"
    }
  }
}

module "ecs_codedeploy" {
  source = "../../"
  container_image_name = "nginx-test"
  container_image_tag  = var.docker_tag
  deployment_name      = "awsecswithcodedeploybasic"
}