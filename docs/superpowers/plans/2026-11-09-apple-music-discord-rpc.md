# Apple Music Discord Rich Presence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS sistem tepsisi uygulaması — Apple Music'ten çalan şarkıyı okuyup Discord rich presence olarak gösterir; dock'ta görünmez, tepsiden çıkış yapılabilir.

**Architecture:** Swift `.app` bundle, `LSUIElement = YES` ile dock'suz çalışır. `NSStatusItem` ile tepsi ikonunu yönetir ve her 2 saniyede AppleScript ile Apple Music'i sorgular. Embedded Go binary, Discord Unix socket (IPC) üzerinden rich presence günceller; Swift bu binary'yi başlatır ve JSON satırları ile iletişim kurar.

**Tech Stack:** Swift 5.9+, AppKit, AppleScript bridge, Go 1.21+, Discord IPC (Unix socket, no third-party lib)

**Spec:** Bu plan kendi spec'idir; tasarım kararları aşağıda belgelenmiştir.

## Global Constraints

- macOS 13+ hedef
- Dock ikonu gösterilmez (`LSUIElement = YES` Info.plist'te)
- Dış bağımlılık yok: Go binary stdlib-only, Swift zero pods/SPM
- Discord uygulaması açık değilse sessizce hata verir, çökmez
- Apple Music açık değilse tepsi menüsü "Şu an çalmıyor" gösterir
- Go binary `Resources/` klasörüne embed, Swift `Bundle.main` üzerinden bulur

## Review Focus

- Apple Music kapalıyken AppleScript sorgusu → "Şu an çalmıyor" göster, crash yok
- Discord kapalıyken IPC bağlantısı → sessiz hata, tepsi normale döner, retry
- Şarkı değişmediğinde Discord'a gereksiz yenileme gönderilmez (dedup)
- Uygulama zaten çalışırken ikinci kez açılırsa → ikinci instance kapanır (single-instance)
- macOS Sonoma+ AppleScript izin diyaloğu → kullanıcıya yönlendirme göster

---

## File Structure

```
applemusicRPS/
├── AppMusicRPS/                    # Xcode project root
│   ├── AppMusicRPS.xcodeproj/
│   ├── Info.plist
│   ├── AppDelegate.swift           # NSApplication entry, LSUIElement
│   ├── StatusBarController.swift   # NSStatusItem, menü, polling loop
│   ├── AppleMusicBridge.swift      # AppleScript sorgular, TrackInfo model
│   ├── DiscordBridge.swift         # Go binary yönetimi, JSON IPC
│   └── Resources/
│       └── discord-rpc             # Compiled Go binary (embed)
└── discord-rpc-go/                 # Go kaynak kodu
    ├── main.go                     # stdin JSON okur, Discord IPC yazar
    └── ipc.go                      # Discord Unix socket IPC impl
```

---

### Task 1: Go Discord IPC Binary

**Files:**
- Create: `discord-rpc-go/ipc.go`
- Create: `discord-rpc-go/main.go`

**Interfaces:**
- Consumes: stdin JSON satırları `{"title":"...","artist":"...","album":"...","playing":true}`
- Produces: compiled binary `discord-rpc-go/discord-rpc` (Task 4'te embed edilir)

Discord IPC protokolü: `/tmp/discord-ipc-{0..9}` Unix socket; her frame `[opcode u32le][length u32le][json payload]`. Handshake opcode=0, payload `{"v":1,"client_id":"CLIENT_ID"}`. Activity set opcode=1.

**Discord Application:** Kullanıcı https://discord.com/developers/applications adresinden uygulama oluşturup client ID almalı. Plan'da placeholder `"YOUR_CLIENT_ID"` kullanılır; binary build öncesi değiştirilir.

- [ ] **Step 1: Go modülü başlat**

```bash
cd discord-rpc-go
go mod init discord-rpc
```

- [ ] **Step 2: `ipc.go` yaz**

`ipc.go` içinde:
```go
package main

import (
    "encoding/binary"
    "encoding/json"
    "net"
    "fmt"
)

func connectDiscord() (net.Conn, error) // /tmp/discord-ipc-0..9 dene
func writeFrame(conn net.Conn, opcode uint32, payload any) error // u32le header + json
func readFrame(conn net.Conn) (opcode uint32, data []byte, err error)
```

`connectDiscord`: 0..9 arası socket dener, ilk başarılı bağlantıyı döner, hepsi başarısızsa error.

- [ ] **Step 3: `main.go` yaz**

```go
const clientID = "YOUR_CLIENT_ID"

type TrackInfo struct {
    Title   string `json:"title"`
    Artist  string `json:"artist"`
    Album   string `json:"album"`
    Playing bool   `json:"playing"`
}
```

Akış:
1. `connectDiscord()` çağır
2. Handshake frame gönder (opcode=0), cevap oku
3. `bufio.Scanner` ile stdin'den JSON satırı oku
4. Her satırda `TrackInfo` parse et
5. `playing=true` ise activity set frame gönder; `false` ise activity clear (opcode=1, boş assets)
6. Discord bağlantısı düşerse stderr'e yaz, `os.Exit(1)` (Swift yeniden başlatır)

Activity payload örneği:
```json
{
  "cmd": "SET_ACTIVITY",
  "args": {
    "pid": <os.Getpid()>,
    "activity": {
      "details": "<title>",
      "state": "<artist>",
      "assets": {"large_image": "appicon", "large_text": "<album>"}
    }
  },
  "nonce": "1"
}
```

- [ ] **Step 4: Build et ve test**

```bash
cd discord-rpc-go
go build -o discord-rpc .
echo '{"title":"Test","artist":"Artist","album":"Album","playing":true}' | ./discord-rpc
```

Discord açıksa rich presence güncellenir. Discord kapalıysa `stderr` hatası, sıfır crash.

- [ ] **Step 5: Commit**

```bash
git add discord-rpc-go/
git commit -m "feat: Discord IPC Go binary"
```

---

### Task 2: Xcode Projesi ve Info.plist

**Files:**
- Create: `AppMusicRPS/Info.plist`
- Create: `AppMusicRPS/AppDelegate.swift`

**Interfaces:**
- Produces: çalışan ama boş `.app` — dock'ta görünmez, tepside ikonla

- [ ] **Step 1: Xcode projesi oluştur**

Xcode'da: File → New → Project → macOS → App  
Product Name: `AppMusicRPS`, Interface: `XIB` değil, doğrudan `AppDelegate`  
Bundle ID: `com.yourname.applemusicrps`

- [ ] **Step 2: `Info.plist`'e ekle**

```xml
<key>LSUIElement</key>
<true/>
<key>NSAppleEventsUsageDescription</key>
<string>Apple Music'teki şarkı bilgilerini okumak için gereklidir.</string>
```

- [ ] **Step 3: `AppDelegate.swift` yaz**

```swift
import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard
        let running = NSWorkspace.shared.runningApplications
        let count = running.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }.count
        if count > 1 { NSApp.terminate(nil) }

        statusBarController = StatusBarController()
    }
}
```

- [ ] **Step 4: Build et, dock'ta görünmediğini doğrula**

`Cmd+R` ile çalıştır; Dock'ta uygulama ikonu çıkmamalı.

- [ ] **Step 5: Commit**

```bash
git add AppMusicRPS/
git commit -m "feat: Xcode project scaffold, LSUIElement dock-less"
```

---

### Task 3: AppleScript Bridge

**Files:**
- Create: `AppMusicRPS/AppleMusicBridge.swift`

**Interfaces:**
- Produces:
  ```swift
  struct TrackInfo: Equatable {
      let title: String
      let artist: String
      let album: String
      let isPlaying: Bool
  }
  
  class AppleMusicBridge {
      func currentTrack() -> TrackInfo? // nil = Music.app kapalı
  }
  ```

- [ ] **Step 1: `AppleMusicBridge.swift` yaz**

AppleScript sorgusu:
```applescript
tell application "Music"
    if it is running then
        set t to name of current track
        set ar to artist of current track
        set al to album of current track
        set st to player state
        return t & "\n" & ar & "\n" & al & "\n" & (st as string)
    end if
end tell
```

Swift'te `NSAppleScript` ile çalıştır, sonucu `\n` ile split et, `TrackInfo` döndür. `player state = playing` ise `isPlaying = true`.

`currentTrack()` hata alırsa `nil` döner (Music.app kapalı veya izin yok).

- [ ] **Step 2: İzin diyaloğu testi**

İlk çalıştırmada macOS Automation izni sorar; uygulama System Settings'e yönlendirme mesajı göstermeli. Bunu Task 4'te `StatusBarController` içinde ele alacağız.

- [ ] **Step 3: Unit test (opsiyonel, manuel)**

Music.app'i çalıştır, şarkı başlat, Xcode console'da `currentTrack()` çıktısını gözlemle.

- [ ] **Step 4: Commit**

```bash
git add AppMusicRPS/AppleMusicBridge.swift
git commit -m "feat: AppleScript bridge for Apple Music"
```

---

### Task 4: Status Bar Controller ve Polling

**Files:**
- Create: `AppMusicRPS/StatusBarController.swift`

**Interfaces:**
- Consumes: `AppleMusicBridge.currentTrack() -> TrackInfo?`
- Consumes: `DiscordBridge` (Task 5'ten)
- Produces: `NSStatusItem` ile çalışan tepsi ikonu + menü

Menü öğeleri:
- `[şarkı adı - sanatçı]` (disabled, sadece bilgi)
- Separator
- `Çıkış` → `NSApp.terminate(nil)`

- [ ] **Step 1: `StatusBarController.swift` iskelet**

```swift
import AppKit

class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var lastTrack: TrackInfo?
    private let musicBridge = AppleMusicBridge()
    private var discordBridge: DiscordBridge?

    init() {
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        buildMenu(track: nil)
        startPolling()
    }
}
```

- [ ] **Step 2: `buildMenu(track:)` yaz**

`track == nil` → menü ilk satırı "Şu an çalmıyor"  
`track != nil, !isPlaying` → "⏸ title - artist"  
`track != nil, isPlaying` → "▶ title - artist"

- [ ] **Step 3: `startPolling()` yaz**

```swift
func startPolling() {
    timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        self?.poll()
    }
    timer?.fire()
}

func poll() {
    let track = musicBridge.currentTrack()
    guard track != lastTrack else { return } // dedup
    lastTrack = track
    buildMenu(track: track)
    discordBridge?.send(track: track)
}
```

- [ ] **Step 4: AppleScript izin hatası handling**

`currentTrack()` nil dönerse ve ilk sorgu ise: `NSAlert` göster → "System Settings > Privacy > Automation > AppMusicRPS'e izin ver"

- [ ] **Step 5: Build et, tepsi ikonunu doğrula**

Uygulama çalışırken tepside ikon görünmeli, menü açılmalı, Çıkış çalışmalı.

- [ ] **Step 6: Commit**

```bash
git add AppMusicRPS/StatusBarController.swift
git commit -m "feat: status bar controller with polling and dedup"
```

---

### Task 5: Discord Bridge (Swift tarafı)

**Files:**
- Create: `AppMusicRPS/DiscordBridge.swift`
- Modify: `AppMusicRPS/Resources/` — Go binary ekle

**Interfaces:**
- Consumes: compiled `discord-rpc` binary (Task 1)
- Produces:
  ```swift
  class DiscordBridge {
      func send(track: TrackInfo?) // nil = clear presence
  }
  ```

- [ ] **Step 1: Go binary'yi Resources'a kopyala**

```bash
cp discord-rpc-go/discord-rpc AppMusicRPS/Resources/discord-rpc
```

Xcode'da `Resources` grubuna ekle, "Copy if needed" seçili olsun.

- [ ] **Step 2: `DiscordBridge.swift` yaz**

```swift
import Foundation

class DiscordBridge {
    private var process: Process?
    private var stdin: Pipe?

    init() { startProcess() }

    private func startProcess() {
        guard let binaryURL = Bundle.main.url(forResource: "discord-rpc", withExtension: nil) else { return }
        let p = Process()
        p.executableURL = binaryURL
        let input = Pipe()
        p.standardInput = input
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self?.startProcess() // Discord kapandıysa 5 sn sonra retry
            }
        }
        try? p.run()
        process = p
        stdin = input
    }

    func send(track: TrackInfo?) {
        guard let stdin else { return }
        let payload: [String: Any]
        if let t = track, t.isPlaying {
            payload = ["title": t.title, "artist": t.artist, "album": t.album, "playing": true]
        } else {
            payload = ["playing": false]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else { return }
        stdin.fileHandleForWriting.write(Data((line + "\n").utf8))
    }
}
```

- [ ] **Step 3: `StatusBarController`'a entegre et**

`StatusBarController.init()` içinde `discordBridge = DiscordBridge()` ekle.

- [ ] **Step 4: Uçtan uca test**

1. Discord aç
2. Apple Music'te şarkı başlat
3. Uygulamayı çalıştır
4. Discord profilinde rich presence görün

- [ ] **Step 5: Commit**

```bash
git add AppMusicRPS/DiscordBridge.swift AppMusicRPS/Resources/discord-rpc
git commit -m "feat: Discord bridge, embed Go binary, full flow"
```

---

### Task 6: Polish ve Edge Cases

**Files:**
- Modify: `AppMusicRPS/StatusBarController.swift`
- Modify: `AppMusicRPS/AppDelegate.swift`

**Interfaces:**
- Consumes: tüm önceki task'lar

- [ ] **Step 1: Uygulama kapanışında presence temizle**

`AppDelegate.applicationWillTerminate` içinde `discordBridge.send(track: nil)`.

- [ ] **Step 2: Uzun şarkı isimlerini kısalt**

Tepsi menüsünde başlık 40 karakteri geçerse `"..."` truncate.

- [ ] **Step 3: Tepsi ikonu duruma göre değişsin**

Çalıyorsa `music.note`, duruyorsa `pause.fill` SF Symbol.

- [ ] **Step 4: Final test**

- [ ] Music.app kapalıyken başlat → "Şu an çalmıyor"
- [ ] Discord kapalıyken başlat → sessiz hata, tepsi çalışıyor
- [ ] Şarkı değişmeden tekrar poll → Discord'a gereksiz gönderim yok
- [ ] İkinci instance aç → kapanır
- [ ] Çıkış → presence temizlenir

- [ ] **Step 5: Son commit**

```bash
git add -u
git commit -m "feat: polish, edge cases, presence cleanup on exit"
```
