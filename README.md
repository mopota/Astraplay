<img width="1402" height="1122" alt="WhatsApp Image 2026-07-02 at 3 16 24 AM" src="https://github.com/user-attachments/assets/2878a555-b480-4757-a14a-391d1fcf1a95" />


# AstraPlay - Premium IPTV Streaming Application

A complete, production-ready IPTV streaming application built with Flutter using Feature-First Clean Architecture.

## Features

- **Material 3 UI**: Modern OTT experience with Glassmorphism and smooth animations.
- **Multi-Source Support**: M3U URLs, Local Files, and Xtream Codes API.
- **Powerful Player**: Built on `media_kit` supporting M3U8, MKV, MP4, etc.
- **Database**: Local storage using `Drift` (SQLite) for high performance.
- **State Management**: `flutter_bloc` for predictable state.
- **Clean Architecture**: Decoupled layers for easy maintenance and scaling.

## Project Structure

- `lib/core`: Shared utilities, theme, routing, and database.
- `lib/features`: 
  - `home`: Dashboard with favorites and history.
  - `playlist`: Management of imported playlists.
  - `category`: Automatic categorization of streams.
  - `player`: Custom video player module.
  - `source_management`: Unified "Add Source" experience.
  - `search`: Global search through all content.
  - `settings`: App-wide configuration.

## Getting Started

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run Code Generation**:
   Since the project uses `drift` and `json_serializable`, you must run the build runner:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Run the App**:
   ```bash
   flutter run
   ```

## Requirements Met

- [x] Material 3 Design
- [x] Responsive for Mobile & Android TV
- [x] M3U & Xtream Support
- [x] Global Search
- [x] Custom Player with Gestures
- [x] Feature First Clean Architecture
- [x] Background Parsing (Isolates)
- [x] Favorites & History
- [x] Dynamic Colors & Dark Mode
