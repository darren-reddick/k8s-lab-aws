

data "aws_ami" "ubuntu_server" {
  most_recent      = true
  owners           = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["Ubuntu Server 18.04 LTS*"]
  }


}