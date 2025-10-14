#!/usr/bin/env bash
set -euo pipefail

# sudo systemctl restart docker
IF_A=enp0s8
IF_B=enp0s9
sudo iptables -A OUTPUT -o enp0s9 -d 192.168.58.0/24 -j DROP
# drop enp0s8 sent to server enp0s9
sudo iptables -A OUTPUT -o enp0s8 -d 192.168.59.0/24 -j DROP

sudo iptables -A OUTPUT -o enp0s3 -d 192.168.58.0/24 -j DROP
sudo iptables -A OUTPUT -o enp0s3 -d 192.168.59.0/24 -j DROP
