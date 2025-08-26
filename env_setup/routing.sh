#!/usr/bin/env bash
set -euo pipefail

# ==== 依你的環境調整（如需） ====
TAB_A=n6A; TAB_B=n6B
IF_A=enp0s8; IF_B=enp0s9            # host 的兩張實體/host-only 卡
SRV_A=192.168.56.20; SRV_B=192.168.57.20
HOST_A=192.168.56.10; HOST_B=192.168.57.10
BR=br-free5gc                        # free5gc 的 docker bridge 名稱
RULE_A_PRIO=900; RULE_B_PRIO=901

# ==== 抓容器目前 IP（動態） ====
UPF1_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' upf)
UPF2_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' upf2)
echo "UPF1_IP=${UPF1_IP}  UPF2_IP=${UPF2_IP}"

# ==== rt_tables 條目（若無才追加） ====
grep -qE "^[[:space:]]*100[[:space:]]+${TAB_A}\$" /etc/iproute2/rt_tables || echo "100 ${TAB_A}" | sudo tee -a /etc/iproute2/rt_tables >/dev/null
grep -qE "^[[:space:]]*200[[:space:]]+${TAB_B}\$" /etc/iproute2/rt_tables || echo "200 ${TAB_B}" | sudo tee -a /etc/iproute2/rt_tables >/dev/null

# add route rule in specified table:  if dst is SRV_A/B use interface IF_A/B to send
sudo ip route replace ${SRV_A%.*}.0/24 dev ${IF_A} scope link table ${TAB_A}
sudo ip route replace ${SRV_B%.*}.0/24 dev ${IF_B} scope link table ${TAB_B}
sudo ip route replace ${SRV_A}/32 dev ${IF_A} src ${HOST_A} table ${TAB_A}
sudo ip route replace ${SRV_B}/32 dev ${IF_B} src ${HOST_B} table ${TAB_B}

# ==== 先刪掉舊的 ip rule（用 priority 清乾淨再重加） ====
sudo ip rule del priority ${RULE_A_PRIO} 2>/dev/null || true
sudo ip rule del priority ${RULE_B_PRIO} 2>/dev/null || true

# if packet src is from UPF1/2_IP use table TAB_A/B to find corresponding rules.
sudo ip rule add from ${UPF1_IP}/32 table ${TAB_A} priority ${RULE_A_PRIO}
sudo ip rule add from ${UPF2_IP}/32 table ${TAB_B} priority ${RULE_B_PRIO}

# ==== 建議開啟轉送 & RPF 放寬（多宿/非對稱路徑）
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
sudo sysctl -w net.ipv4.conf.all.rp_filter=2 >/dev/null
sudo sysctl -w net.ipv4.conf.${IF_A}.rp_filter=2 >/dev/null
sudo sysctl -w net.ipv4.conf.${IF_B}.rp_filter=2 >/dev/null

# ==== 清快取 + 顯示核對 ====
sudo ip route flush cache
ip rule
ip route show table ${TAB_A}
ip route show table ${TAB_B}

# 用「iif bridge」模擬轉送情境做路徑驗證（應各自落到對應 oif）
sudo ip route get ${SRV_A} from ${UPF1_IP} iif ${BR}
sudo ip route get ${SRV_B} from ${UPF2_IP} iif ${BR}
