variable aws_region_name {
  type = string
  default = "us-east-2"
  description = "The region in which all resources are deployed."
}

variable container_image_name {
  type = string
  default = ""
  description = "The name of the Docker image to use, including the full repository URL if required."
}

variable container_image_tag {
  type = string
  default = "latest"
  description = "The tag of the Docker image to use."
}

variable container_environment_variables {
  type = list(
    object({
      name = string
      value = string
    })
  )
  description = "An array of environment variable names and values to be passed in to the container definition."
  default = []
}

variable container_secrets {
  type = list(
    object({
      name = string
      valueFrom = string
    })
  )
  description = "An array of secret names and SSM parameter ARNs to be passed in to the container definition."
  default = []
}

variable container_cpu {
  type = number
  description = "The CPU units to assign to the container task. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size."
  default = 256
}

variable container_memory {
  type = number
  description = "The memory units to assign to the container task. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size."
  default = 512
}

variable desired_count {
  type = number
  description = "The number of desired container instances."
  default = 1
}

variable task_exec_role_policies {
  type = list(string)
  description = "A list of additional policy ARNs to be attached to the task execution role for the ECS tasks."
  default = []
}

variable task_role_policies {
  type = list(string)
  description = "A list of policie ARNs to be attached to the task role for the ECS tasks."
  default = []
}

variable vpc_id {
  type = string
  default = ""
  description = "The ID of the VPC in which resources are deployed."
}

variable subnet_ids {
  type = list(string)
  default = []
  description = "A list of Subnet IDs in which resources will be deployed."
}

variable deployment_name {
  type = string
  default = ""
  description = "An arbitrary name for the deployment."
}

variable tags {
  type = map(string)
  default = {}
  description = "A list of tags to apply to all resources."
}

variable lb_certificate_arn {
  type = string
  default = ""
  description = "The ARN of a certificate to be used on the Elastic Load Balancer. If blank, an HTTPS listener will not be created."
}

variable ssl_policy {
  type = string
  default = ""
  description = "The SSL Policy to apply to the ALB. Only used if the 'lb_certificate_arn' variable is set. See https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies for details."
}

variable health_check_path {
  type = string
  default = "/"
  description = "The path to use for the container health check."
}

variable health_check_timeout {
  type = number
  default = 5
  description = "The number of seconds to wait for a response from the health check endpoint."
}

variable health_check_interval {
  type = number
  default = 10
  description = "The number of seconds in between health checks."
}

variable security_group_ids {
  type = list(string)
  description = "A list of security group IDs that should be assigned to the ECS tasks. If left blank, then a new security group will be created with basic HTTP ingress rules."
  default = []
}