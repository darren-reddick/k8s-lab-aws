# k8s-lab-aws

Terraform project to build a K8S lab cluster in AWS.

<p style align="left">
<img width="100" height="100" src="https://kubernetes.io/images/favicon.png">
<img width="100" height="100" src="https://static8.depositphotos.com/1479444/945/v/950/depositphotos_9450328-stock-illustration-mad-professor.jpg">
</p>

## Overview

This project is to be a quick and easy way to spin up a kubernetes cluster in AWS.

The motivation behind this is to have a quick lab environment for:
* Trying out features in versions not supported by the managed versions
* A learning environment for one of the Kubernetes certifications
* Breaking / fixing / experimenting with the control plane


## Usage

### Prerequisites

Make sure you have installed all of the following prerequisites on your machine:

* Terraform - [Download & Install](https://www.terraform.io/downloads.html) terraform (version 0.13 recommended). 
* An AWS account
* AWSCLI - [Download & Install](https://aws.amazon.com/cli/) the aws cli.

...or use the dockerized workflow which requires:

* Docker - [Download & Install](https://docs.docker.com/get-docker/) docker

### Quick start

Clone the gitHub repository

```
git clone https://github.com/darren-reddick/k8s-lab-aws.git
```

Set the AWS_PROFILE variable to the relevant profile
```
export AWS_PROFILE=[myprofile]
```

Initialize Terraform

```
cd k8s-lab-aws/
terraform init
```

Terraform apply
```
terraform apply
```

This will create the cluster infrastructure and return the ssh connection details for the nodes. 
Connection to the nodes is possible at this time but there is a bunch of stuff going on in the background to create the K8S cluster. This will normally take about 5 mins to complete.

Once this process is complete you should be able to check the status of the nodes in the cluster:
```
KUBECONFIG=/etc/kubernetes/admin.conf sudo -E kubectl get no
```

### Dockerized workflow

The terraform init and apply steps above can be run in a docker container so the tools dont have to installed locally.

Substitute those steps with the following:

```
make tf-init
make tf-plan
make tf-apply
```


### How it works

* The terraform code creates Ubuntu LTS 16 EC2 instances
* The **userdata** on the master:
    * Configures the OS
    * Installs packages
    * initializes as a Kubernetes master using kubeadm
    * [Calico](https://www.projectcalico.org/) is installed for container networking 
    * Creates a cluster join config in an S3 bucket using kubeadm
* The **userdata** on the node(s):
    * Configures the OS
    * Installs packages
    * Pulls the cluster join config from the S3 bucket
    * Joins the cluster using the config and kubeadm
* An ssh key pair is created in the local **secrets/** directory which is used for sshing to the nodes

### Kubernetes Versions

So far this has been tested on:
* 1.18.16
* 1.19.8
* 1.20.0

The terraform variable k8s_version is restricted to those that have been tested. This can be overridden just by updating the validation array.

## The Future

Currently this is a pretty raw incarnation that works with Ubuntu LTS 16, the K8S versions previously listed (single master) on a t2.medium instance

In the future we could:

* Support spot instances: (for cheapskates :0) I have done this on other projects with a bit of hacking around.
* Specify instance type
* HA Control plane: I have also done this before but it wasnt pretty
* Some CI for at least terraform fmt




