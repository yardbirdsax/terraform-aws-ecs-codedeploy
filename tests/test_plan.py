import unittest
import tftest
from pprint import pprint

class TestPlan(unittest.TestCase):

  tf_dir = "../terraform"
  subnet_ids = ["a","b"]
  vpc_id = "abcdef"
  
  @classmethod
  def setUpClass(self):
    
    self.tf = tftest.TerraformTest(self.tf_dir)
    self.tf.setup(extra_files=['./test_plan.auto.tfvars'])
    self.tf_output = self.tf.plan(output=True)

  def test_alb_uses_subnets(self):
    assert self.tf_output.resources["aws_lb.elb"]['values']['subnets'] == self.subnet_ids
  
  def test_alb_listener_uses_vpc(self):
    assert self.tf_output.resources["aws_lb_target_group.target_group_blue"]["values"]["vpc_id"] == self.vpc_id
    assert self.tf_output.resources["aws_lb_target_group.target_group_green"]["values"]["vpc_id"] == self.vpc_id

  def test_ecs_task_uses_subnets(self):
    #pprint(self.tf_output.resources["aws_ecs_service.ecs_service"])
    assert self.tf_output.resources["aws_ecs_service.ecs_service"]["values"]["network_configuration"][0]["subnets"] == self.subnet_ids