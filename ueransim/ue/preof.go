package main

import (
	"context"
	"flag"
	"fmt"
	"hash/fnv"
	"log"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/songgao/water"
	"github.com/songgao/water/waterutil"
	"golang.org/x/sys/unix"
)

/*
 最速版要點：
 - 不加任何自訂表頭；UDP payload = 內層 IP 封包（從 TUN 讀到的 bytes）
 - 去重：以 64-bit hash(內層整包) + 時間窗 LRU，避免雙路重複進 kernel
 - 兩條出站 UDP socket 用 SO_MARK=0x1/0x2，配合 policy routing 綁定 A1/A2
 - 兩條入站各自 Listen（rx1, rx2），讀到後做去重→寫回 TUN
*/

var (
	flagTun   = flag.String("tun", "tun0", "TUN device name")
	flagMTU   = flag.Int("mtu", 1400, "TUN MTU (set via ip link)")

	flagTX1   = flag.String("tx1", "", "peer1 UDP addr host:port (e.g. 192.168.58.20:6001)")
	flagTX2   = flag.String("tx2", "", "peer2 UDP addr host:port (e.g. 192.168.59.20:6002)")
	flagMark1 = flag.Int("mark1", 0x1, "fwmark for tx1 socket")
	flagMark2 = flag.Int("mark2", 0x2, "fwmark for tx2 socket")

	flagRX1 = flag.String("rx1", "", "local listen addr path1 (e.g. :7001 or :6001)")
	flagRX2 = flag.String("rx2", "", "local listen addr path2 (e.g. :7002 or :6002)")

	flagWinDur = flag.Duration("win", 300*time.Millisecond, "dedup window duration")
	flagMaxEnt = flag.Int("max", 65536, "dedup max entries")
	flagQSize  = flag.Int("q", 2048, "ingress queue size")
)

/******** UDP helpers ********/
func dialUDPWithMark(remote string, mark int) (*net.UDPConn, *net.UDPAddr, error) {
	peer, err := net.ResolveUDPAddr("udp", remote)
	if err != nil {
		return nil, nil, err
	}
	conn, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4zero, Port: 0})
	if err != nil {
		return nil, nil, err
	}
	rc, _ := conn.SyscallConn()
	rc.Control(func(fd uintptr) {
		_ = unix.SetsockoptInt(int(fd), unix.SOL_SOCKET, unix.SO_MARK, mark)
	})
	return conn, peer, nil
}
func listenUDP(bind string) (*net.UDPConn, error) {
	laddr, err := net.ResolveUDPAddr("udp", bind)
	if err != nil {
		return nil, err
	}
	return net.ListenUDP("udp", laddr)
}

/******** Dedup by content hash + time window ********/
type dedupEntry struct{ t time.Time }
type deduper struct {
	mu     sync.Mutex
	win    time.Duration
	max    int
	table  map[uint64]dedupEntry
	orders []uint64
}

func newDeduper(win time.Duration, max int) *deduper {
	return &deduper{
		win:   win,
		max:   max,
		table: make(map[uint64]dedupEntry, max),
	}
}
func (d *deduper) dropOrKeep(pkt []byte, now time.Time) bool {
	// 哈希整個內層 IP 包（TUN 中不會變 TTL/校驗，因此雙路複本 bitwise 相同）
	h := fnv.New64a()
	h.Write(pkt)
	key := h.Sum64()

	d.mu.Lock()
	defer d.mu.Unlock()

	if ent, ok := d.table[key]; ok {
		if now.Sub(ent.t) <= d.win {
			return true // drop (duplicate within window)
		}
	}
	// keep & 記錄
	d.table[key] = dedupEntry{t: now}
	d.orders = append(d.orders, key)
	// 簡單淘汰：超過 max 就按插入順序清舊（並檢視時間窗）
	if len(d.table) > d.max {
		cut := len(d.orders) - d.max
		if cut < 0 { cut = 0 }
		for i := 0; i < cut && i < len(d.orders); i++ {
			k := d.orders[i]
			if now.Sub(d.table[k].t) > d.win {
				delete(d.table, k)
			}
		}
		if cut > 0 && cut < len(d.orders) {
			d.orders = d.orders[cut:]
		}
	}
	return false
}

/******** main ********/
func main() {
	flag.Parse()
	if *flagTX1 == "" || *flagTX2 == "" || *flagRX1 == "" || *flagRX2 == "" {
		fmt.Fprintf(os.Stderr, "Usage: %s -tun tun0 -mtu 1400 -tx1 host:6001 -mark1 0x1 -tx2 host:6002 -mark2 0x2 -rx1 :7001 -rx2 :7002\n", os.Args[0])
		os.Exit(2)
	}

	// 開 TUN
	cfg := water.Config{
		DeviceType: water.TUN,
		PlatformSpecificParams: water.PlatformSpecificParams{
			Name: *flagTun,
		},
	}
	tun, err := water.New(cfg)
	if err != nil {
		log.Fatalf("open TUN %s: %v", *flagTun, err)
	}
	log.Printf("TUN %s opened (set MTU to %d via ip link)", *flagTun, *flagMTU)

	// 出站兩路
	tx1, peer1, err := dialUDPWithMark(*flagTX1, *flagMark1)
	if err != nil { log.Fatalf("tx1 %s: %v", *flagTX1, err) }
	tx2, peer2, err := dialUDPWithMark(*flagTX2, *flagMark2)
	if err != nil { log.Fatalf("tx2 %s: %v", *flagTX2, err) }
	log.Printf("TX1->%s (mark=0x%x), TX2->%s (mark=0x%x)", peer1, *flagMark1, peer2, *flagMark2)

	// 入站兩路
	rx1, err := listenUDP(*flagRX1)
	if err != nil { log.Fatalf("listen %s: %v", *flagRX1, err) }
	rx2, err := listenUDP(*flagRX2)
	if err != nil { log.Fatalf("listen %s: %v", *flagRX2, err) }
	log.Printf("RX1 on %s, RX2 on %s", rx1.LocalAddr(), rx2.LocalAddr())

	// Ctrl+C
	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		c := make(chan os.Signal, 1)
		signal.Notify(c, os.Interrupt, syscall.SIGTERM)
		<-c
		cancel()
	}()

	// 送：TUN -> 兩個 UDP（payload=內層IP）
	go func() {
		buf := make([]byte, 65535)
		for {
			n, err := tun.Read(buf)
			if err != nil {
				if ctx.Err()!=nil { return }
				log.Printf("tun read: %v", err)
				continue
			}
			inner := buf[:n]
			// 可選：降 MTU 已避免超 MTU；或檢查 n<=*flagMTU
			_, _ = tx1.WriteToUDP(inner, peer1)
			_, _ = tx2.WriteToUDP(inner, peer2)
		}
	}()

	// 收：兩路 UDP -> 去重 -> TUN
	ded := newDeduper(*flagWinDur, *flagMaxEnt)
	ing := make(chan []byte, *flagQSize)

	recv := func(c *net.UDPConn, tag string) {
		buf := make([]byte, 65535)
		for {
			n, _, err := c.ReadFromUDP(buf)
			if err != nil {
				if ctx.Err()!=nil { return }
				log.Printf("%s read: %v", tag, err)
				continue
			}
			b := make([]byte, n)
			copy(b, buf[:n])
			select {
			case ing <- b:
			case <-ctx.Done(): return
			}
		}
	}
	go recv(rx1, "rx1")
	go recv(rx2, "rx2")

	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case p := <-ing:
				now := time.Now()
				if ded.dropOrKeep(p, now) {
					continue // duplicate，丟
				}
				// 粗過濾：確保是 IP（避免雜訊）
				if !(waterutil.IsIPv4(p) || waterutil.IsIPv6(p)) {
					continue
				}
				if _, err := tun.Write(p); err != nil {
					log.Printf("tun write: %v", err)
				}
			}
		}
	}()

	log.Printf("dup-tunnel (UDP, no-seq) running. Ctrl+C to stop.")
	<-ctx.Done()
	_ = rx1.Close(); _ = rx2.Close()
	_ = tx1.Close(); _ = tx2.Close()
	log.Printf("stopped.")
}
