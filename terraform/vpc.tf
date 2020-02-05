data aws_vpc vpc {
  default = true
}

data aws_availability_zones azs {
  state = "available"
}

data aws_subnet subnet {
  count = length(data.aws_availability_zones.azs.names)
  vpc_id = data.aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.azs.names[count.index]
}