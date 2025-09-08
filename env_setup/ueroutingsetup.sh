# don't need
echo "100 pduA" | tee -a /etc/iproute2/rt_tables
echo "200 pduB" | tee -a /etc/iproute2/rt_tables
ip route add default dev uesimtun0 table pduA
ip route add default dev uesimtun1 table pduB
ip rule add from 10.60.0.1/32 table pduA priority 1000
ip rule add from 10.63.0.1/32 table pduB priority 1001
ip rule list
ip route show table pduA
ip route show table pduB
