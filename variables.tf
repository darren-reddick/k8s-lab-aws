variable "region" {
  default = "eu-west-1"
}

variable "environment" {
  default = "devops"
}

variable "k8s_version" {
  default = "1.19.8-00"
  description = "The kubernetes version identifier"

  validation {
    condition     = contains(["1.19.8-00","1.20.0-00","1.18.16-00"],var.k8s_version)
    error_message = "The k8s_version specified has not been tested.\nThis can be overridden by updating the condition in the validation for k8s_version."
  }
}