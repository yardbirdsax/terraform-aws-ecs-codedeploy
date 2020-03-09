import unittest
import tftest
from pprint import pprint
import json

class TestPlan(unittest.TestCase):

  tf_dir = "../terraform"
  subnet_ids = ["a","b"]
  vpc_id = "abcdef"
  deployment_name = "testdeployment"
  container_image_name = "nginx"
  container_image_tag = "latest"
  certificate_arn = "arn:aws:cert:something"
  aws_region = "us-east-1"

  env_var_1_name = "MY_FIRST_VAR"
  env_var_1_value = "VALUE"
  env_var_2_name = "MY_SECOND_VAR"
  env_var_2_value = "VALUE2"

  secret_var_1_name = "MY_FIRST_SECRET"
  secret_var_1_value = "ARN:VALUE"
  secret_var_2_name = "MY_SECOND_SECRET"
  secret_var_2_value = "ARN:VALUE2"

  desired_count = 1
  container_cpu = 512
  container_memory = 1024
  
  @classmethod
  def setUpClass(self):
    
    self.tf = tftest.TerraformTest(self.tf_dir)
    self.tf.setup(extra_files=['./test_plan.auto.tfvars'])
    self.tf_output = self.tf.plan(output=True)

  def test_alb_uses_subnets(self):
    assert self.tf_output.resources["aws_lb.elb"]['values']['subnets'] == self.subnet_ids
  
  def test_alb_tg_uses_vpc(self):
    assert self.tf_output.resources["aws_lb_target_group.target_group_blue"]["values"]["vpc_id"] == self.vpc_id
    assert self.tf_output.resources["aws_lb_target_group.target_group_green"]["values"]["vpc_id"] == self.vpc_id
  
  def test_alb_listener_uses_cert_arn(self):
    assert self.tf_output.resources['aws_lb_listener.elb_listener_https[0]']['values']['certificate_arn'] == self.certificate_arn

  def test_ecs_task_uses_subnets(self):
    #pprint(self.tf_output.resources["aws_ecs_service.ecs_service"])
    assert self.tf_output.resources["aws_ecs_service.ecs_service"]["values"]["network_configuration"][0]["subnets"] == self.subnet_ids

  def test_security_group_name(self):
    assert self.tf_output.resources["aws_security_group.security_group_web"]["values"]["name"] == self.deployment_name

  def test_ecs_task_uses_docker_image(self):
    container_defs = json.loads(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["container_definitions"])
    assert container_defs[0]["image"] == f"{self.container_image_name}:{self.container_image_tag}"

  def test_iam_role_name(self):
    assert self.tf_output.resources['aws_iam_role.ecs_task_role']['values']['name'] == f"{self.deployment_name}-TaskRole"
  
  def test_iam_policy_name(self):
    assert self.tf_output.resources['aws_iam_role_policy.ecs_task_policy']['values']['name'] == f"{self.deployment_name}-TaskPolicy"

  def test_security_group_vpc_id(self):
    assert self.tf_output.resources['aws_security_group.security_group_web']['values']['vpc_id'] == self.vpc_id
  
  def test_ecs_task_uses_vars(self):
    container_defs = json.loads(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["container_definitions"])
    assert len(container_defs[0]['environment']) == 2
    assert container_defs[0]['environment'][0]['name'] == self.env_var_1_name
    assert container_defs[0]['environment'][1]['name'] == self.env_var_2_name
    assert container_defs[0]['environment'][0]['value'] == self.env_var_1_value
    assert container_defs[0]['environment'][1]['value'] == self.env_var_2_value

  def test_ecs_task_uses_secrets(self):
    container_defs = json.loads(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["container_definitions"])
    assert len(container_defs[0]['secrets']) == 2
    assert container_defs[0]['secrets'][0]['name'] == self.secret_var_1_name
    assert container_defs[0]['secrets'][1]['name'] == self.secret_var_2_name
    assert container_defs[0]['secrets'][0]['valueFrom'] == self.secret_var_1_value
    assert container_defs[0]['secrets'][1]['valueFrom'] == self.secret_var_2_value
  
  def test_ecs_task_log_group(self):
    container_defs = json.loads(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["container_definitions"])
    assert container_defs[0]['logConfiguration']['options']['awslogs-group'] == f"/ecs/{self.deployment_name}"
    assert container_defs[0]['logConfiguration']['options']['awslogs-region'] == self.aws_region

  def test_ecs_task_cpu(self):
    container_defs = json.loads(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["container_definitions"])
    assert int(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["cpu"]) == self.container_cpu
    assert container_defs[0]['cpu'] == self.container_cpu

  def test_ecs_task_memory(self):
    container_defs = json.loads(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["container_definitions"])
    assert int(self.tf_output.resources["aws_ecs_task_definition.ecs_task"]["values"]["memory"]) == self.container_memory
    assert container_defs[0]['memory'] == self.container_memory

  def test_ecs_service_count(self):
    assert self.tf_output.resources["aws_ecs_service.ecs_service"]["values"]["desired_count"] == 1