module "ssh_key_pair" {
  source                = "cloudposse/ssh-key-pair/tls"
  version               = "0.6.0"
  stage                 = "devops"
  name                  = "cks-lab"
  ssh_public_key_path   = "secrets"
  private_key_extension = ".pem"
  public_key_extension  = ".pub"
  chmod_command         = "chmod 600 %v"
}


resource "aws_key_pair" "cks-lab" {
  key_name   = "cks-lab"
  public_key = module.ssh_key_pair.public_key
}