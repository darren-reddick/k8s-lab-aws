resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu_server.id
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.cks-lab.key_name
  subnet_id              = module.vpc.public_subnets.0
  vpc_security_group_ids = [aws_security_group.k8s-node.id]
  iam_instance_profile   = aws_iam_instance_profile.kubemaster-instance-profile.id
  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
  }
  tags = {
    Name                           = join("", [var.environment, "-kubemaster"])
    Terraform                      = "true"
    Environment                    = var.environment
    "kubernetes.io/cluster/ckslab" = "owned"
  }
  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
  user_data = <<FOE
Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.apt_update}

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.install_bins}

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.kubeadm_master}

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.join_script}

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
    cidr_blocks = [join("/", [module.myip.address, "32"])]
  }
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
  ingress {
    from_port = 10250
    to_port   = 10250
    protocol  = "tcp"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
}

output "master_public_dns" {
  value = aws_instance.master.public_dns
}

// S3 bucket for exchange of the cluster join config between master and worker
resource "aws_s3_bucket" "join-cluster" {
  acl = "private"

  tags = {
    Terraform   = "true"
    Name        = "cks-lab-join-cluster"
    Environment = var.environment
  }
  // clean up our bucket before we delete it
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOD
aws s3 rm s3://${self.id}/join-config.yaml
EOD
  }
}




data "aws_caller_identity" "current" {}

resource "aws_iam_role" "kubemaster-instance-role" {
  name               = join("", [var.environment, "-kubemaster-instance-role"])
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "kubemaster-instance-profile" {
  name = join("", [var.environment, "-kubemaster-instance-profile"])
  path = "/"
  role = aws_iam_role.kubemaster-instance-role.name
}

resource "aws_iam_role_policy_attachment" "kubemaster-instance-role-attachment1" {
  role       = aws_iam_role.kubemaster-instance-role.name
  policy_arn = aws_iam_policy.kubemaster.arn
}

resource "aws_iam_policy" "kubemaster" {
  name        = join("", [var.environment, "-kubemaster-policy"])
  path        = "/"
  description = "Policy for kubemaster"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVolume",
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateRoute",
                "ec2:DeleteRoute",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteVolume",
                "ec2:DetachVolume",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DescribeVpcs",
                "iam:CreateServiceLinkedRole",
                "kms:DescribeKey",
                "elasticloadbalancing:*"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.join-cluster.arn}/*"
        }
    ]
}
EOF
}

resource "aws_instance" "node" {
  ami                    = data.aws_ami.ubuntu_server.id
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.cks-lab.key_name
  subnet_id              = module.vpc.public_subnets.0
  vpc_security_group_ids = [aws_security_group.k8s-node.id]
  iam_instance_profile   = aws_iam_instance_profile.kubenode-instance-profile.id
  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
  }
  tags = {
    Name                           = join("", [var.environment, "-kubenode"])
    Terraform                      = "true"
    Environment                    = var.environment
    "kubernetes.io/cluster/ckslab" = "owned"
  }
  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
  user_data = <<FOE
Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.apt_update}

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.install_bins}

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash

${local.user_data.join_cluster}

FOE
}


output "node_public_dns" {
  value = aws_instance.node.public_dns
}


resource "aws_iam_role" "kubenode-instance-role" {
  name               = join("", [var.environment, "-kubenode-instance-role"])
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "kubenode-instance-profile" {
  name = join("", [var.environment, "-kubenode-instance-profile"])
  path = "/"
  role = aws_iam_role.kubenode-instance-role.name
}

resource "aws_iam_role_policy_attachment" "kubenode-instance-role-attachment1" {
  role       = aws_iam_role.kubenode-instance-role.name
  policy_arn = aws_iam_policy.kubenode.arn
}

resource "aws_iam_policy" "kubenode" {
  name        = join("", [var.environment, "-kubenode-policy"])
  path        = "/"
  description = "Policy for kubenode"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": "${aws_s3_bucket.join-cluster.arn}/join-config.yaml"
        },
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes"
            ],
            "Resource" : "*"
        }
    ]
}
EOF
}




