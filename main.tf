module "mycluster" {
  source      = "./cluster"
  environment = var.environment
  k8s_version = "1.19.8-00"
}

variable "environment" {
  default = "devops"
}

output "connect-to-master" {
  value = join("", ["ssh -i secrets/", var.environment, "-", module.mycluster.key_name, ".pem ubuntu@", module.mycluster.master_public_dns])
}

output "connect-to-node1" {
  value = join("", ["ssh -i secrets/", var.environment, "-", module.mycluster.key_name, ".pem ubuntu@", module.mycluster.node_public_dns])
}



