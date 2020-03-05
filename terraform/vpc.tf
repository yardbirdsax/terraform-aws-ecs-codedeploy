data aws_vpc vpc {
  default = true
  count = var.vpc_id == "" ? 1 : 0
}

data aws_availability_zones azs {
  state = "available"
}

data aws_subnet subnet {
  count = var.vpc_id == "" ? length(data.aws_availability_zones.azs.names) : 0
  vpc_id = data.aws_vpc.vpc[0].id
  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

locals {
  vpc_id = var.vpc_id == "" ? data.aws_vpc.vpc[0].id : var.vpc_id
}
