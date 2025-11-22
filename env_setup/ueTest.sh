ping -I ueTun1 192.168.58.20 -c 3
ping -I ueTun2 192.168.59.20 -c 3

./dp-udp/ueSetRouting.sh
