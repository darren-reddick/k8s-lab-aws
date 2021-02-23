module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "cks-lab"
  cidr = "10.66.0.0/16"
  enable_dns_hostnames = true

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  public_subnets = ["10.66.11.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = var.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
