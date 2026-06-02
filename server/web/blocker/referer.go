package blocker

import (
	"bufio"
	"net"
	"net/url"
	"strings"
)

var defaultBlockedReferers = []string{
	"bylampa.online",
}

func blockedReferersFromFile(buf []byte) []string {
	fileHosts := scanRefererBuf(buf)
	if len(defaultBlockedReferers) == 0 {
		return fileHosts
	}
	seen := make(map[string]struct{}, len(defaultBlockedReferers)+len(fileHosts))
	blocked := make([]string, 0, len(defaultBlockedReferers)+len(fileHosts))
	for _, host := range defaultBlockedReferers {
		host = strings.ToLower(strings.TrimSpace(host))
		if host == "" {
			continue
		}
		if _, ok := seen[host]; ok {
			continue
		}
		seen[host] = struct{}{}
		blocked = append(blocked, host)
	}
	for _, host := range fileHosts {
		if _, ok := seen[host]; ok {
			continue
		}
		seen[host] = struct{}{}
		blocked = append(blocked, host)
	}
	return blocked
}

func scanRefererBuf(buf []byte) []string {
	if len(buf) == 0 {
		return nil
	}
	var hosts []string
	scanner := bufio.NewScanner(strings.NewReader(string(buf)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		hosts = append(hosts, strings.ToLower(line))
	}
	return hosts
}

func hostFromHeader(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	u, err := url.Parse(value)
	if err != nil {
		return ""
	}
	host := strings.ToLower(u.Host)
	if host == "" {
		return ""
	}
	if h, _, err := net.SplitHostPort(host); err == nil {
		return h
	}
	return host
}

func hostMatchesBlocked(host string, blocked []string) bool {
	host = strings.ToLower(strings.TrimSpace(host))
	if host == "" {
		return false
	}
	for _, blockedHost := range blocked {
		if blockedHost == "" {
			continue
		}
		if host == blockedHost || strings.HasSuffix(host, "."+blockedHost) {
			return true
		}
	}
	return false
}

func isBlockedReferer(referer string, origin string, blocked []string) (blockedHost string, ok bool) {
	if host := hostFromHeader(referer); host != "" {
		if hostMatchesBlocked(host, blocked) {
			return host, true
		}
	}
	if host := hostFromHeader(origin); host != "" {
		if hostMatchesBlocked(host, blocked) {
			return host, true
		}
	}
	return "", false
}
