sudo ip addr flush dev enp0s8
sudo ip addr flush dev enp0s9

sudo ip link set enp0s8 promisc on
sudo ip addr add 192.170.10.10/24 dev enp0s8
sudo ip route add 192.170.20.0/24 dev enp0s8