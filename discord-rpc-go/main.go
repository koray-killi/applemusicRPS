package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
)

const clientID = "1569121258849697832"

type TrackInfo struct {
	Title   string `json:"title"`
	Artist  string `json:"artist"`
	Album   string `json:"album"`
	Playing bool   `json:"playing"`
	Start   int64  `json:"start"`
	End     int64  `json:"end"`
}

func artworkURL(title, artist string) string {
	for _, q := range []string{title + " " + artist, artist} {
		resp, err := http.Get("https://itunes.apple.com/search?term=" + url.QueryEscape(q) + "&entity=song&limit=1")
		if err != nil {
			continue
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		var result struct {
			Results []struct {
				ArtworkUrl100 string `json:"artworkUrl100"`
			} `json:"results"`
		}
		if err := json.Unmarshal(body, &result); err != nil || len(result.Results) == 0 {
			continue
		}
		u := result.Results[0].ArtworkUrl100
		if len(u) > 13 {
			u = u[:len(u)-13] + "512x512bb.jpg"
		}
		return u
	}
	return ""
}

func main() {
	conn, err := connectDiscord()
	if err != nil {
		fmt.Fprintln(os.Stderr, "discord connect error:", err)
		os.Exit(1)
	}
	defer conn.Close()

	handshake := map[string]any{"v": 1, "client_id": clientID}
	if err := writeFrame(conn, 0, handshake); err != nil {
		fmt.Fprintln(os.Stderr, "handshake write error:", err)
		os.Exit(1)
	}
	if _, _, err := readFrame(conn); err != nil {
		fmt.Fprintln(os.Stderr, "handshake read error:", err)
		os.Exit(1)
	}

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
			imgURL := artworkURL(track.Title, track.Artist)
			assets := map[string]any{
				"large_text":  track.Album,
				"small_image": "https://cdn.discordapp.com/app-assets/1569121258849697832/1569162438811717783.png",
				"small_text":  "Apple Music",
			}
			if imgURL != "" {
				assets["large_image"] = imgURL
			} else {
				assets["large_image"] = "appicon"
			}
			activity := map[string]any{
				"type":    2,
				"details": track.Title,
				"state":   track.Artist,
				"assets":  assets,
			}
			if track.Start > 0 {
				activity["timestamps"] = map[string]any{"start": track.Start}
			}
			payload = map[string]any{
				"cmd":   "SET_ACTIVITY",
				"args":  map[string]any{"pid": os.Getpid(), "activity": activity},
				"nonce": fmt.Sprintf("%d", nonce),
			}
		} else {
			payload = map[string]any{
				"cmd":   "SET_ACTIVITY",
				"args":  map[string]any{"pid": os.Getpid(), "activity": nil},
				"nonce": fmt.Sprintf("%d", nonce),
			}
		}

		if err := writeFrame(conn, 1, payload); err != nil {
			fmt.Fprintln(os.Stderr, "write error:", err)
			os.Exit(1)
		}
	}
}
