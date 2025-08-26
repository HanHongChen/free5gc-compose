sudo sysctl -w net.mptcp.mptcp_enabled=1
sudo sysctl -w net.mptcp.mptcp_scheduler=redundant
sudo sysctl -w net.mptcp.mptcp_path_manager=fullmesh
echo 2 | sudo tee /sys/module/mptcp_fullmesh/parameters/num_subflows
sudo sysctl -w net.ipv4.conf.all.rp_filter=2
sudo sysctl -w net.ipv4.conf.enp0s8.rp_filter=2
sudo sysctl -w net.ipv4.conf.enp0s9.rp_filter=2
