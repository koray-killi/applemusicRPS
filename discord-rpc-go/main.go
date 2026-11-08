package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
)

const clientID = "1569121258849697832"

type TrackInfo struct {
	Title   string `json:"title"`
	Artist  string `json:"artist"`
	Album   string `json:"album"`
	Playing bool   `json:"playing"`
}

func main() {
	conn, err := connectDiscord()
	if err != nil {
		fmt.Fprintln(os.Stderr, "discord connect error:", err)
		os.Exit(1)
	}
	defer conn.Close()

	// Handshake
	handshake := map[string]any{"v": 1, "client_id": clientID}
	if err := writeFrame(conn, 0, handshake); err != nil {
		fmt.Fprintln(os.Stderr, "handshake write error:", err)
		os.Exit(1)
	}
	if _, _, err := readFrame(conn); err != nil {
		fmt.Fprintln(os.Stderr, "handshake read error:", err)
		os.Exit(1)
	}

	// Drain Discord responses in background (one long-lived goroutine)
	go func() {
		for {
			if _, _, err := readFrame(conn); err != nil {
				return
			}
		}
	}()

	nonce := 0
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		var track TrackInfo
		if err := json.Unmarshal([]byte(scanner.Text()), &track); err != nil {
			fmt.Fprintln(os.Stderr, "json parse error:", err)
			continue
		}

		nonce++
		var payload map[string]any
		if track.Playing {
			payload = map[string]any{
				"cmd": "SET_ACTIVITY",
				"args": map[string]any{
					"pid": os.Getpid(),
					"activity": map[string]any{
						"details": track.Title,
						"state":   track.Artist,
						"assets": map[string]any{
							"large_image": "appicon",
							"large_text":  track.Album,
						},
					},
				},
				"nonce": fmt.Sprintf("%d", nonce),
			}
		} else {
			payload = map[string]any{
				"cmd": "SET_ACTIVITY",
				"args": map[string]any{
					"pid":      os.Getpid(),
					"activity": nil,
				},
				"nonce": fmt.Sprintf("%d", nonce),
			}
		}

		if err := writeFrame(conn, 1, payload); err != nil {
			fmt.Fprintln(os.Stderr, "write error:", err)
			os.Exit(1)
		}
	}
}
