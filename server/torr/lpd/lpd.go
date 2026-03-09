// Package lpd implements BEP 14: Local Peer Discovery (LPD).
// It allows discovering torrent peers on the same local network via UDP multicast.
// See: http://bittorrent.org/beps/bep_0014.html
package lpd

import (
	"bufio"
	"bytes"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/anacrolix/torrent"
	"github.com/anacrolix/torrent/metainfo"

	"server/log"
	"server/settings"
)

const (
	bep14Host4 = "239.192.152.143:6771"
	bep14Host6 = "[ff15::efc0:988f]:6771"
	// BEP 14 recommends max 1 announce per minute; we use 2s for responsiveness when starting/stopping
	announceInterval = 2 * time.Second
	// When no torrents to announce
	idleInterval = 5 * time.Minute
)

// Server implements Local Peer Discovery (BEP 14)
type Server struct {
	client *torrent.Client
	port   int

	conn4   *net.UDPConn
	conn6   *net.UDPConn
	stopCh chan struct{}
	wg     sync.WaitGroup
	mu     sync.Mutex

	// Get active torrents - returns map of infohash -> *torrent.Torrent
	getTorrents func() map[metainfo.Hash]*torrent.Torrent
	// Get our listen port for announcements
	getListenPort func() int
}

// New creates a new LPD server. It does not start listening until Start() is called.
func New(client *torrent.Client, getTorrents func() map[metainfo.Hash]*torrent.Torrent, getListenPort func() int) *Server {
	return &Server{
		client:       client,
		getTorrents:  getTorrents,
		getListenPort: getListenPort,
	}
}

// Start begins listening for LPD announcements and sending our own.
func (s *Server) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.stopCh != nil {
		return nil // already running
	}

	s.stopCh = make(chan struct{})

	// IPv4 multicast listener
	addr4, err := net.ResolveUDPAddr("udp4", bep14Host4)
	if err != nil {
		log.TLogln("LPD: failed to resolve IPv4 multicast addr:", err)
	} else {
		s.conn4, err = net.ListenMulticastUDP("udp4", nil, addr4)
		if err != nil {
			log.TLogln("LPD: failed to listen on IPv4 multicast:", err)
		} else {
			s.wg.Add(2)
			go func() { s.receiver(s.conn4, "udp4"); s.wg.Done() }()
			go func() { s.announcer(s.conn4, bep14Host4, "udp4"); s.wg.Done() }()
		}
	}

	// IPv6 multicast listener (optional, may not be available on all systems)
	addr6, err := net.ResolveUDPAddr("udp6", bep14Host6)
	if err != nil {
		log.TLogln("LPD: IPv6 multicast not available:", err)
	} else {
		s.conn6, err = net.ListenMulticastUDP("udp6", nil, addr6)
		if err != nil {
			log.TLogln("LPD: failed to listen on IPv6 multicast:", err)
		} else {
			s.wg.Add(2)
			go func() { s.receiver(s.conn6, "udp6"); s.wg.Done() }()
			go func() { s.announcer(s.conn6, bep14Host6, "udp6"); s.wg.Done() }()
		}
	}

	if s.conn4 == nil && s.conn6 == nil {
		return fmt.Errorf("LPD: could not bind to any multicast address")
	}

	log.TLogln("LPD: Local Peer Discovery started")
	return nil
}

// Stop shuts down the LPD server.
func (s *Server) Stop() {
	s.mu.Lock()
	if s.stopCh == nil {
		s.mu.Unlock()
		return
	}
	close(s.stopCh)
	if s.conn4 != nil {
		s.conn4.Close()
		s.conn4 = nil
	}
	if s.conn6 != nil {
		s.conn6.Close()
		s.conn6 = nil
	}
	s.mu.Unlock()
	s.wg.Wait()
	log.TLogln("LPD: Local Peer Discovery stopped")
}

func (s *Server) receiver(conn *net.UDPConn, network string) {
	defer func() {
		if r := recover(); r != nil {
			log.TLogln("LPD receiver panic:", r)
		}
	}()

	buf := make([]byte, 2000)
	for {
		conn.SetReadDeadline(time.Now().Add(time.Minute))
		n, from, err := conn.ReadFromUDP(buf)
		if err != nil {
			select {
			case <-s.stopCh:
				return
			default:
				if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
					continue
				}
				log.TLogln("LPD receiver:", err)
			}
			continue
		}

		req, err := http.ReadRequest(bufio.NewReader(bytes.NewReader(buf[:n])))
		if err != nil {
			continue
		}
		if req.Method != "BT-SEARCH" {
			continue
		}

		ihs := req.Header[http.CanonicalHeaderKey("Infohash")]
		if len(ihs) == 0 {
			continue
		}
		portStr := req.Header.Get("Port")
		if portStr == "" {
			continue
		}
		port, err := strconv.Atoi(portStr)
		if err != nil || port <= 0 {
			continue
		}

		peer := torrent.Peer{
			IP:   append([]byte(nil), from.IP...),
			Port: port,
		}

		s.mu.Lock()
		torrents := s.getTorrents()
		// Add peer to all active torrents - LPD is the primary source for local peers
		for hash, t := range torrents {
			if t != nil {
				t.AddPeers([]torrent.Peer{peer})
				if settings.IsDebug() {
					log.TLogln("LPD: added peer", net.JoinHostPort(from.IP.String(), strconv.Itoa(port)), "to torrent", hash.HexString())
				}
			}
		}
		s.mu.Unlock()
	}
}

func (s *Server) announcer(conn *net.UDPConn, host, network string) {
	addr, err := net.ResolveUDPAddr(network, host)
	if err != nil {
		return
	}

	refresh := idleInterval
	for {
		select {
		case <-s.stopCh:
			return
		case <-time.After(refresh):
		}

		port := s.getListenPort()
		if port <= 0 {
			continue
		}

		s.mu.Lock()
		torrents := s.getTorrents()
		var ihs []string
		for hash, t := range torrents {
			if t != nil {
				select {
				case <-t.Closed():
					// skip closed torrents
				default:
					ihs = append(ihs, strings.ToUpper(hash.HexString()))
				}
			}
		}
		s.mu.Unlock()

		if len(ihs) == 0 {
			refresh = idleInterval
			continue
		}

		// Build BT-SEARCH announcement (BEP 14 format)
		var ihPart strings.Builder
		for _, ih := range ihs {
			ihPart.WriteString("Infohash: " + ih + "\r\n")
		}
		req := fmt.Sprintf("BT-SEARCH * HTTP/1.1\r\nHost: %s\r\nPort: %d\r\n%s\r\n\r\n",
			host, port, ihPart.String())

		_, err = conn.WriteToUDP([]byte(req), addr)
		if err != nil {
			log.TLogln("LPD announcer:", err)
		}

		refresh = announceInterval
	}
}

