locals {
  user_data = {
    apt_update     = <<FOE
apt-get update; apt-get upgrade -y; apt-get dist-upgrade -y; apt-get autoremove -y; apt-get autoclean -y
FOE
    install_bins   = <<FOE

# install awscli
apt  install awscli -y

# turn off swap
swapoff -a

# comment out swap line from fstab
sed -i.bak 's/\(.*swap.*\)/#\1/' /etc/fstab

cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter


# set up k8s sysctl config for bridge
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# install docker
apt  install docker.io -y
systemctl enable docker.service

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl restart docker.service

mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# set up package locations
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF



# install k8s binaries
apt-get update
apt-get install -y kubelet=${var.k8s_version} kubeadm=${var.k8s_version} kubectl=${var.k8s_version} kubernetes-cni
apt-mark hold kubelet kubeadm kubectl
FOE
    kubeadm_master = <<FOE
kubeadm init --config <(cat << EOF
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
apiServer:
  extraArgs:
    cloud-provider: aws
    feature-gates: "ExpandPersistentVolumes=true"
controllerManager:
  extraArgs:
    cloud-provider: aws
    configure-cloud-routes: "false"
networking:
  podSubnet: 192.168.0.0/16
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
nodeRegistration:
  name: $(hostname -f)
  kubeletExtraArgs:
    cloud-provider: aws
EOF
)

# set up the admin config in the bash profile and current environment
export KUBECONFIG=/etc/kubernetes/admin.conf
cat << 'EOF' >> /root/.bash_profile
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF

. /root/.bash_profile


# install calico networking overlay
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml

# install aws storage class
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/storage-class/aws/default.yaml
FOE
    join_script    = <<FOE
# get the join command
join=$(kubeadm token create --print-join-command)

# parse out values from the join command
token=$(sed 's/.\+--token\ \([^\ ]\+\).\+/\1/' <<< $join)
apiserver=$(awk '{print $3}' <<< $join)
discoverytokenca=$(awk '{print $NF}' <<< $join)

# create the join config template
cat << EOF > /tmp/join-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: aws
    kube-reserved: memory=\$${kubereservedmem}Gi
    enforce-node-allocatable: pods
discovery:
  bootstrapToken:
    apiServerEndpoint: $apiserver
    token: $${token}
    caCertHashes:
    - $${discoverytokenca}
EOF

aws s3 cp /tmp/join-config.yaml s3://${aws_s3_bucket.join-cluster.id}/
FOE
    join_cluster   = <<FOE

# try to get the join config in a loop waiting for join config from master node
ret=0
while [ $ret -eq 0 ]
do
  aws s3 cp s3://${aws_s3_bucket.join-cluster.id}/join-config.yaml /tmp && ret=1
  sleep 30
done


# set reserved memory for kubelet
export kubereservedmem=0.5
# join cluster
kubeadm join --config <(envsubst < /tmp/join-config.yaml) --node-name $(hostname -f)
FOE
  }
}

