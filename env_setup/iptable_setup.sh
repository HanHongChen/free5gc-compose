#!/usr/bin/env bash
set -euo pipefail

# sudo systemctl restart docker
IF_A=enp0s8
IF_B=enp0s9

# drop enp0s9 sent to server enp0s8
sudo iptables -A OUTPUT -o enp0s9 -d 192.168.56.0/24 -j DROP
# drop enp0s8 sent to server enp0s9
sudo iptables -A OUTPUT -o enp0s8 -d 192.168.57.0/24 -j DROP

sudo iptables -A OUTPUT -o enp0s3 -d 192.168.56.0/24 -j DROP
sudo iptables -A OUTPUT -o enp0s3 -d 192.168.57.0/24 -j DROP

UPF1_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' upf)
UPF2_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' upf2)
UE1_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ueransim)
UE2_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ueransim2)

echo "UPF1_IP=${UPF1_IP}  UPF2_IP=${UPF2_IP} UE1_IP=${UE1_IP} UE2_IP=${UE2_IP}"

# 插在最前面，確保優先於 Docker 自動加的那條 10.100.200.0/24 MASQUERADE
# if src is upf1 and dst is interfaceA then nat
sudo iptables -t nat -I POSTROUTING 1 -s ${UPF1_IP}/32 -o ${IF_A} -j MASQUERADE
sudo iptables -t nat -I POSTROUTING 1 -s ${UPF2_IP}/32 -o ${IF_B} -j MASQUERADE

sudo iptables -I FORWARD 1 -s ${UPF1_IP}/32 -d 192.168.56.0/24 -j ACCEPT
sudo iptables -I FORWARD 1 -s ${UPF1_IP}/32 -d 192.168.57.0/24 -j DROP
sudo iptables -I FORWARD 1 -s ${UPF2_IP}/32 -d 192.168.57.0/24 -j ACCEPT
sudo iptables -I FORWARD 1 -s ${UPF2_IP}/32 -d 192.168.56.0/24 -j DROP

sudo iptables -I FORWARD 3 -m state --state ESTABLISHED,RELATED -j ACCEPT

sudo iptables -I FORWARD 4 -s ${UE1_IP}/32 -d 192.168.56.20/32 -j DROP
sudo iptables -I FORWARD 4 -s ${UE1_IP}/32 -d 192.168.57.20/32 -j DROP
sudo iptables -I FORWARD 4 -s ${UE2_IP}/32 -d 192.168.56.20/32 -j DROP
sudo iptables -I FORWARD 4 -s ${UE2_IP}/32 -d 192.168.57.20/32 -j DROP


# 顯示結果（確認你的兩條在最上面 & 計數有跳）
sudo iptables -L -n -v --line-numbers
sudo iptables -t nat -L POSTROUTING -n -v --line-numbers | sed -n '1,80p'
