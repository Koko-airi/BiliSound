# BiliSound (哔哩纯音) - iOS Bilibili Music Player

A modern, high-performance iOS music player designed for streaming music directly from Bilibili with pure audio extraction, multi-version track mapping, single-session fair shuffle, seamless Bilibili favorites import, local playlist persistence, and full lock-screen media controls.

Compatible with **iOS 17.0+ / iOS 18.x / iOS 26+** (optimized for all iPhone screen sizes, including iPhone 13 Pro notch & Dynamic Island devices).

---

## 🌟 Key Features

### 🎧 1. Pure "Music Player Mode" by Default (Zero Video Overhead)
- **Audio-Only Streaming**: Fetches Bilibili's DASH manifest (`fnval=16`) from the official PlayURL API (`https://api.bilibili.com/x/player/playurl`) and extracts the pure audio stream (`dash.audio`), completely discarding video data.
- **Bandwidth & Battery Efficient**: Saves up to **85% data and CPU cycles** compared to regular video streaming; prevents phone overheating and unwanted screen wakeups.
- **CDN Anti-Leech Protection Bypass**: Automatically injects required HTTP headers (`Referer: https://www.bilibili.com/video/<BVID>` and Mobile Safari `User-Agent`) via `BilibiliAudioProxy` and `AVURLAssetHTTPHeaderFieldsKey` to eliminate HTTP 403 CDN errors.
- **Background Playback**: Configured with `UIBackgroundModes: audio` and `AVAudioSession(category: .playback)` for continuous background listening while your device is locked or when switching between apps.

---

### 🔐 2. Bilibili Account Authentication & VIP High-Bitrate Audio
- **Seamless Account Login**: Integrated `BiliAccountManager` and `BilibiliLoginSheet` support official Bilibili Web Login (QR code app scan, SMS code, password) as well as manual cookie (`SESSDATA`) entry.
- **High-Bitrate Audio Stream Access**: Authenticated sessions unlock VIP audio streams up to **192kbps / 320kbps / Hi-Res DASH** and completely eliminate guest WAF rate-limiting challenges.
- **Live Account Status**: Real-time display of your avatar, nickname, UID, and VIP tier badge in the Account tab.

---

### ☁️ 3. Bilibili Playlist & Favorites Import
- **One-Tap Library Import**: Directly browse your Bilibili account's **Created Favorites (我的收藏)** and **Subscribed Favorites (订阅的收藏)** via `ImportBiliPlaylistSheet`.
- **Batch Track Fetching**: Automatically paginates through collection folders, converting video metadata (`bvid`, `title`, uploader, duration, thumbnail) into local playable songs.
- **Smart Song Version Naming**: Imported songs default their version label to the actual title of the Bilibili video rather than generic text.
- **Playlist-Specific Song Merging with Deduplication**: From inside any playlist's settings, you can import songs from your Bilibili folders directly into that playlist. Any videos already present (matched by BV ID or normalized title) are automatically skipped to prevent duplicates.

---

### 💾 4. Robust Local Playlist Persistence
- **Persistent Storage Manager**: All playlists, custom added tracks, and multi-version mappings are atomically saved to local sandboxed JSON storage (`user_playlists.json`) via `PlaylistStorageManager`.
- **Zero Data Loss**: Playlists and multi-version customizations persist across full app restarts and system memory reclaims.
- **Safe Deletion**: Accidental single-swipe deletions on the main library are disabled. Playlists can only be deleted through a dedicated `"playlist settings"` page with an explicit confirmation dialog.

---

### 🔀 5. Playback Modes & Session Non-Repeating Guarantee
Supports three distinct playback states:
1. **Sequential Order (`.sequential`)**: Plays songs in normal order ($1 \to 2 \to 3 \to \dots \to N$).
2. **Session Shuffle (`.shuffle`)**: Fair random autoplay with **single-session non-repeating guarantees**:
   ```swift
   let eligibleCandidates = playlist.songs.filter { !session.hasPlayed(songId: $0.id) }
   ```
   A song played in the current listening session will **never repeat** until every other track in the playlist has been played.
3. **Repeat One (`.repeatOne`)**: Loops the current track/version continuously.
- **Session Progress Badge & Log**: Tap the session status pill to open `SessionHistoryView` showing real-time session elapsed time, percentage of playlist completed, chronological history, and remaining candidate pool.

---

### 🎲 6. Multi-Version Song Mapping (Feature Highlight)
Songs on Bilibili often exist in multiple formats (Studio MV, World Tour live concert, acoustic one-take, piano cover, remix).
- **Multi-Version Data Architecture**: A single `Song` holds an array of `[SongVersion]`:
  ```swift
  public struct SongVersion: Identifiable, Codable {
      public var name: String          // e.g. "2007 World Tour Live Concert"
      public var bvid: String          // e.g. "BV1Zp4y1a7uZ"
      public var uploader: String      // e.g. "Jay Chou"
      public var duration: TimeInterval
      public var audioQuality: String  // e.g. "192kbps DASH"
      public var isEnabled: Bool       // Active in random version pool
      public var weight: Double        // Relative probability weight
  }
  ```
- **Weighted Random Roll**: Whenever a track plays, `song.selectRandomVersion()` randomly selects one of its active versions.
- **Re-Roll Version Button (`🎲`)**: Instantly re-rolls a different version of the currently playing song with one tap in the player or mini bar.
- **Version Manager Sheet**: Easily inspect all versions of any song, adjust selection weights, toggle versions on/off, or paste a new Bilibili BV URL to attach another version.

---

### 🎛️ 7. Full-Screen Player & Transport Controls
- **Interactive Scrubber**: Draggable progress bar (`ScrubberBar`) with live timestamp badge (`min:sec / total:sec`), elapsed time, and remaining time calculation.
- **Safe Area & Display Optimized**: Tuned for rounded corners, top status bar, iPhone 13 Pro notch (47pt), and Dynamic Island with zero UI clipping.
- **Jump Forward / Backward 5s**: Instant `±5s` audio skipping (`gobackward.5` and `goforward.5`).
- **Speed Selector**: Variable playback speed menu supporting `0.75x`, `1.0x`, `1.25x`, `1.5x`, and `2.0x`.
- **System Lock Screen & Dynamic Island**: Full integration with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` (remote play, pause, scrubbing, track change, and artwork display).

---

## 📁 Project Architecture

```
BiliSound/
├── BiliSound.xcodeproj/              # Xcode Project configuration
│   └── project.pbxproj
├── BiliSound/
│   ├── App/
│   │   ├── BiliSoundApp.swift        # App Entry Point & dark theme configuration
│   │   └── Info.plist                # Background Audio & ATS exceptions
│   ├── Models/
│   │   ├── PlaybackMode.swift        # Sequential, Shuffle, RepeatOne
│   │   ├── SongVersion.swift         # Multi-version video metadata & BV ID
│   │   ├── Song.swift                # Track entity with weighted version picker
│   │   ├── PlaySession.swift         # Session history & non-repeat pool
│   │   └── Playlist.swift            # Playlist collection model
│   ├── Services/
│   │   ├── PlaylistStorageManager.swift # Sandboxed JSON persistence engine
│   │   ├── BiliAccountManager.swift     # QR/Web login & SESSDATA cookie session
│   │   ├── BilibiliAPIService.swift     # DASH extraction, metadata & favorites API
│   │   ├── BilibiliURLParser.swift      # URL & BV ID regex parser
│   │   ├── BilibiliAudioProxy.swift     # Anti-leech HTTP header injector
│   │   └── SampleData.swift             # Verified multi-version starter playlists
│   ├── Player/
│   │   ├── AudioPlayerManager.swift     # AVPlayer playback coordinator & state machine
│   │   └── NowPlayingManager.swift      # Lock Screen & MPRemoteCommandCenter controls
│   ├── Views/
│   │   ├── MainTabView.swift            # Primary tab navigation & docked mini player
│   │   ├── PlaylistsView.swift          # Library view with custom & imported playlists
│   │   ├── PlaylistDetailView.swift     # Tracklist, shuffle actions & settings footer
│   │   ├── PlaylistSettingsView.swift   # Dedicated playlist settings, import & safe delete
│   │   ├── FullScreenPlayerView.swift   # Vinyl artwork player & transport controls
│   │   ├── NowPlayingMiniBar.swift      # Docked bottom mini-player bar
│   │   ├── SongRowView.swift            # Song row with version badge & re-roll action
│   │   ├── VersionManagerSheet.swift    # Multi-version configuration & weights sheet
│   │   ├── ImportBiliPlaylistSheet.swift# Bilibili favorites folder picker & importer
│   │   ├── BilibiliLoginSheet.swift     # Official Web Login & manual cookie modal
│   │   ├── SessionHistoryView.swift     # Fair shuffle session inspector
│   │   ├── AddSongSheet.swift           # Direct Bilibili URL/BV song attachment sheet
│   │   └── Components/
│   │       ├── ScrubberBar.swift        # Touch-draggable progress bar
│   │       ├── GlassControls.swift      # Glassmorphic control buttons
│   │       ├── AnimatedArtworkView.swift# Rotating vinyl with ambient glow
│   │       └── VersionBadge.swift       # Interactive multi-version counter pill
│   └── Resources/
│       └── Assets.xcassets/             # Colors & App Icon assets
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites
- macOS Sonoma or newer
- **Xcode 15.0+** or **Xcode 16.0+**
- iOS Simulator or physical iPhone running **iOS 17.0+**

### Running the App
1. Clone or open the repository folder.
2. Double-click `BiliSound.xcodeproj` to open the project in Xcode.
3. Select your target device or simulator (e.g., **iPhone 13 Pro**, **iPhone 15 Pro**, **iPhone 16 Pro**).
4. Press **Cmd + R** to build and run.
5. *(Optional for physical devices)*: Under **BiliSound target > Signing & Capabilities**, choose your Apple ID development team.

---

## 💡 Quick Tips
- **Instant Audio Stream**: Go to the **Quick Stream** tab and paste any Bilibili video URL or BV ID (`BV...`) to stream pure DASH audio immediately.
- **Importing Your Playlists**: Log into your Bilibili account in the **Account & Settings** tab, then tap **"Import"** on the Library screen to download your personal collection folders.
- **Multi-Version Switching**: Tap on the version pill (e.g. `🎲 2 versions`) in any song row or the dice icon on the player screen to re-roll or customize song versions.
