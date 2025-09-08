sudo ip addr flush dev enp0s8
sudo ip addr flush dev enp0s9

sudo ip link set enp0s8 promisc on
sudo ip link set enp0s9 promisc on

sudo ip addr add 192.168.56.10/24 dev enp0s8
sudo ip route add 192.168.56.0/24 dev enp0s8
sudo ip route add 192.168.58.0/24 dev enp0s8

sudo ip addr add 192.168.57.10/24 dev enp0s9
sudo ip route add 192.168.57.0/24 dev enp0s9
sudo ip route add 192.168.59.0/24 dev enp0s9