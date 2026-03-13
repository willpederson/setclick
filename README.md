# SetClick 🎵

The click track app built for gigging musicians. Create your song library, organize setlists, and go live with a performance-ready metronome.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/setclick/id6742843885)

## Features

### 🎵 Song Library
Store every song with its BPM, time signature, key, subdivision, click sound, count-in beats, duration, and performance notes. Tap tempo to find the BPM by feel.

### 📋 Setlist Manager
Build setlists for each gig. Add songs, reorder them, duplicate for tomorrow's show. Export and share setlists with your band.

### 🎯 Live Mode
Full-screen performance view designed for dark stages. Beat ring visualization, current & next song display, BPM, key, and live countdown timer. Skip forward and back without leaving the screen.

### 🔒 Lock Screen Controls
Play, pause, and skip songs from the lock screen and Now Playing widget. No need to unlock your phone mid-set.

### 🤫 Count-Off Only
Get the count-in to set the tempo, then silence. For bands that want to start together but play without a running click.

### 📳 Haptic Feedback
Feel every beat through your phone. Heavy pulse on the downbeat, lighter taps on the rest.

### 🔐 Completely Private
All data is stored on your device. No accounts, no cloud, no tracking.

## Screenshots

<p align="center">
  <img src=".github/screenshots/songs.png" width="200" />
  <img src=".github/screenshots/setlists.png" width="200" />
  <img src=".github/screenshots/editor.png" width="200" />
  <img src=".github/screenshots/livemode.png" width="200" />
</p>

## Requirements

- iOS 17.0+
- iPad supported
- Xcode 16+
- Swift 5.9+

## Tech Stack

- **SwiftUI** — declarative UI
- **SwiftData** — local persistence
- **AVAudioEngine** — low-latency audio playback
- **MediaPlayer** — Now Playing & lock screen integration
- **CoreHaptics** — beat haptic feedback

## Building

1. Clone the repo
2. Open `SetClick.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build & Run

No external dependencies. No CocoaPods. No SPM packages.

## Privacy

SetClick stores all data locally on your device using SwiftData. There are no analytics, no tracking, no network requests, and no accounts. See the full [Privacy Policy](https://willpederson.github.io/setclick/privacy.html).

## Website

[willpederson.github.io/setclick](https://willpederson.github.io/setclick/)

## License

Copyright © 2026 Will Pederson. All rights reserved.

---

Built with 🥁 for musicians who take the stage seriously.
