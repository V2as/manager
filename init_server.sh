#!/bin/bash
apt update && apt upgrade -y
apt install make gcc -y
apt install build-essential curl git wget -y
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

mkdir -p /opt/go
cd /opt/go
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
source /etc/profile

git clone https://github.com/amnezia-vpn/amneziawg-go.git /opt/amnezia-go
cd /opt/amnezia-go
make
cp /opt/amnezia-go/amneziawg-go /usr/bin/amneziawg-go

git clone https://github.com/amnezia-vpn/amneziawg-tools.git /opt/amnezia-tools
cd /opt/amnezia-tools/src
make
make install


