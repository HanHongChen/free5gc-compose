#!/bin/bash

# 參數
DURATION=60
INTERVAL=10

IFACE=eth0


tc qdisc add dev $IFACE root handle 1: netem delay 0ms 2>/dev/null || true

LOOPS=$((DURATION / INTERVAL))

for ((i=0; i<$LOOPS; i++)); do
    if ((i % 2 == 0)); then
        tc qdisc change dev $IFACE root netem loss 100%    
    else
        tc qdisc change dev $IFACE root netem loss 0%
    fi
    sleep $INTERVAL
done

# 全部恢復（loss 0%）
tc qdisc change dev $IFACE root netem loss 0%
echo "upf2恢復"