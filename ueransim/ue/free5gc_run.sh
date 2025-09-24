#!/usr/bin/env bash
set -euo pipefail

# ====== 你的四個 IP（已套）======
A1=10.60.0.1   # free5gc nic1
A2=10.63.0.1   # free5gc nic2
B1=192.168.58.20   # server  nic1
B2=192.168.59.20   # server  nic2

# 內層業務 IP（建議放在 tun0，以免跟 UERANSIM 搶介面）
TUN=tun0
MTU=1400
INNER_A=192.170.10.10/32
INNER_B=192.170.20.10

# 自動找出 A1/A2 的介面名稱
dev_of_ip(){ ip -o -4 addr show | awk -v ip="$1" '$4 ~ ip"/"{print $2; exit}'; }
DEV_A1=$(dev_of_ip "$A1"); DEV_A2=$(dev_of_ip "$A2")
echo "[free5gc] A1=$A1($DEV_A1)  A2=$A2($DEV_A2)"

# 建 TUN，配業務 IP、路由到對端業務 IP
ip tuntap add dev $TUN mode tun 2>/dev/null || true
ip link set $TUN mtu $MTU up
ip addr add $INNER_A dev $TUN 2>/dev/null || true
ip route replace ${INNER_B%/*}/32 dev $TUN src ${INNER_A%/*}

# policy routing：fwmark 走不同卡
grep -q 'nic1tbl' /etc/iproute2/rt_tables || echo "100 nic1tbl" | tee -a /etc/iproute2/rt_tables >/dev/null
grep -q 'nic2tbl' /etc/iproute2/rt_tables || echo "200 nic2tbl" | tee -a /etc/iproute2/rt_tables >/dev/null

ip route replace $B1/32 dev $DEV_A1 table nic1tbl
ip route replace $B2/32 dev $DEV_A2 table nic2tbl
ip rule add fwmark 0x1 table nic1tbl 2>/dev/null || true
ip rule add fwmark 0x2 table nic2tbl 2>/dev/null || true

# 放鬆 rp_filter（避免非對稱被丟）
# for i in all default $DEV_A1 $DEV_A2; do sysctl -q -w net.ipv4.conf.$i.rp_filter=2; done

# 啟動（free5gc 發→B1/B2:6001/6002；收回程 :7001/:7002）
DIR="$(cd "$(dirname "$0")" && pwd)"
exec  "$DIR/dup-tunnel" \
  -tun $TUN -mtu $MTU \
  -tx1 ${B1}:6001 -mark1 0x1 \
  -tx2 ${B2}:6002 -mark2 0x2 \
  -rx1 :7001 \
  -rx2 :7002 \
  -win 300ms -max 65536 -q 2048
