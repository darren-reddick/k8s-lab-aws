resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu_server.id
  instance_type = "t2.medium"
  key_name = aws_key_pair.cks-lab.key_name
  subnet_id = module.vpc.public_subnets.0
  vpc_security_group_ids = [ aws_security_group.k8s-node.id ]
  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
  }
  tags = {
    Terraform = "true"
    Environment = var.environment
  }
  user_data = <<FOE
Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.apt_update}
FOE


}

module myip {
  source  = "4ops/myip/http"
  version = "1.0.0"
}


resource "aws_security_group" "k8s-node" {
  name        = "k8s-node-security-group"
  description = "Security group for k8s-node"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks     = [join("/",[module.myip.address,"32"])]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

output "connect-to-master" {
  value = join("",["ssh -i secrets/",var.environment,"-",aws_key_pair.cks-lab.key_name,".pem ubuntu@",aws_instance.master.public_dns])
}

locals {
  user_data = {
    apt_update = <<FOE
sudo -- sh -c 'apt-get update; apt-get upgrade -y; apt-get dist-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
FOE
  }
}