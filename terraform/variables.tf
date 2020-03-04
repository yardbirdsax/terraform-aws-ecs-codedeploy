variable docker_tag {
  type = string
  default = "1.0"
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