#!/bin/bash

# Set variables values
MASTER_IP=192.168.56.2

# Load necessary kernel modules and configure sysctl
lsmod | grep br_netfilter
sudo modprobe br_netfilter
lsmod | grep br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Disable swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sudo systemctl stop ufw
sudo systemctl disable ufw

  # Ubuntu/Debian specific Docker installation
  sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Configure Docker
  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
  sudo mkdir -p /etc/systemd/system/docker.service.d
  sudo systemctl daemon-reload
  sudo systemctl restart docker
  sudo systemctl enable docker

  # Install and configure containerd
  sudo apt-get update
  sudo apt-get install -y containerd
  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml
  sudo systemctl restart containerd
  sudo systemctl enable containerd

# Ensure the container runtime is running correctly
sudo systemctl status containerd
sudo systemctl status docker

  # Ubuntu/Debian specific Kubernetes installation
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl

  # Ensure set-kubeconfig.sh has the right permissions
  chmod +x /vagrant/set-kubeconfig.sh


# Initialize Kubernetes master


sudo kubeadm init --pod-network-cidr 10.244.0.0/16 --apiserver-advertise-address=$MASTER_IP > /tmp/kubeadm_out.log

# Set up kubeconfig for vagrant user
sudo -u vagrant mkdir -p /home/vagrant/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config

# Deploy a pod network to the cluster
#sudo kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
#kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

#kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s-1.11.yaml
#kubectl apply -f weave-daemonset-k8s-1.11.yaml

cd /vagrant_data
sudo -u vagrant kubectl apply -f weave-daemonset-k8s-1.11.yaml
sleep 30

# Extract join command
grep -A1 'kubeadm join' /tmp/kubeadm_out.log > /vagrant/cltjoincommand.sh
sudo chmod +x /vagrant/cltjoincommand.sh
sleep 10
