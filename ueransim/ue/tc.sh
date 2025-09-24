#!/usr/bin/env bash
set -e

# 兩張介面
IFACE0=enp0s8
IFACE1=enp0s9

# 每個週期 10 秒，共跑 40 秒
DURATION=40
INTERVAL=10

# 先確保兩個介面都有 qdisc
sudo tc qdisc add dev $IFACE0 root handle 1: netem delay 0ms 2>/dev/null || true
sudo tc qdisc add dev $IFACE1 root handle 1: netem delay 0ms 2>/dev/null || true

# echo "開始輪流切換 $IFACE0 / $IFACE1 ..."

for ((t=0; t<$DURATION; t+=$INTERVAL)); do
    if (( (t/INTERVAL) % 2 == 0 )); then
        # echo "[$t 秒] 關閉 $IFACE0 (loss 100%)，開啟 $IFACE1"
        sudo tc qdisc change dev $IFACE0 root netem loss 100%
        sudo tc qdisc change dev $IFACE1 root netem loss 0%
    else
        # echo "[$t 秒] 開啟 $IFACE0，關閉 $IFACE1 (loss 100%)"
        sudo tc qdisc change dev $IFACE0 root netem loss 0%
        sudo tc qdisc change dev $IFACE1 root netem loss 100%
    fi
    sleep $INTERVAL
done

# echo "實驗結束，恢復正常"
sudo tc qdisc change dev $IFACE0 root netem loss 0%
sudo tc qdisc change dev $IFACE1 root netem loss 0%
