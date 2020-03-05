subnet_ids = ["a","b"]
vpc_id = "abcdef"
deployment_name = "testdeployment"
container_image_name = "nginx"
container_image_tag = "latest"
container_environment_variables = [
  {name = "MY_FIRST_VAR", value = "VALUE"},
  {name = "MY_SECOND_VAR", value  = "VALUE2"}
]
lb_certificate_arn = "arn:aws:cert:something"