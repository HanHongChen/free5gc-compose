echo "close first connection"
tc qdisc add dev uesimtun0 root netem loss 100%
sleep 10
echo "close second connection"
tc qdisc add dev uesimtun1 root netem loss 100%
sleep 10

echo "recover"
tc qdisc del dev uesimtun0 root
tc qdisc del dev uesimtun1 root