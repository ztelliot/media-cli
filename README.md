# media-cli

A command-line tool for controlling media playback on macOS.

## Features

- Get information about currently playing media
- Control media playback (play, pause, next, previous, forward, backward, seek)
- Adjust system volume
- List and switch audio output devices

**Disclaimer:** media-cli uses private frameworks, which may cause it to break with future macOS software updates.

**Tested and working on:** macOS 13 Ventura, macOS 14 Sonoma, macOS 15 Sequoia

## Installation

### Using the pre-built binary

```bash
curl -L https://github.com/ztelliot/media-cli/releases/latest/download/media-cli -o ~/.local/bin/media-cli
chmod +x ~/.local/bin/media-cli
```

### Building from source

```bash
git clone https://github.com/ztelliot/media-cli.git
cd media-cli
make
```

## Usage

All commands return data in JSON format.

### Getting Information

```bash
# Get all available information
media-cli get

# Get now playing information
media-cli get nowplaying

# Get specific nowplaying information
media-cli get nowplaying info    # Media metadata
media-cli get nowplaying client  # Client app information
media-cli get nowplaying status  # Playback status

# Get current volume level
media-cli get volume

# Get current audio device
media-cli get device
```

### Controlling Media

```bash
# Play/pause media
media-cli play
media-cli pause
media-cli togglePlayPause

# Skip to next/previous track
media-cli next
media-cli previous

# Skip forward/backward in the current track
media-cli skip 10     # Skip forward 10 seconds
media-cli skip -10    # Skip backward 10 seconds

# Seek to a specific position
media-cli seek 120    # Seek to 2:00 in the track
```

### Volume Control

```bash
# Set volume (0.0-1.0)
media-cli volume 0.5

# Toggle mute
media-cli mute
```

### Audio Device Management

```bash
# List audio devices
media-cli devices

# Set output device
media-cli device DEVICE_ID
```

### Available properties

| native                                          | media-cli           |
|-------------------------------------------------|---------------------|
| kMRMediaRemoteNowPlayingInfoTotalDiscCount      | totalDiscCount      |
| kMRMediaRemoteNowPlayingInfoShuffleMode         | shuffleMode         |
| kMRMediaRemoteNowPlayingInfoTrackNumber         | trackNumber         |
| kMRMediaRemoteNowPlayingInfoDuration            | duration            |
| kMRMediaRemoteNowPlayingInfoRepeatMode          | repeatMode          |
| kMRMediaRemoteNowPlayingInfoTitle               | title               |
| kMRMediaRemoteNowPlayingInfoPlaybackRate        | playbackRate        | 
| kMRMediaRemoteNowPlayingInfoArtworkData         | artworkData         |
| kMRMediaRemoteNowPlayingInfoArtworkDataWidth    | artworkDataWidth    |
| kMRMediaRemoteNowPlayingInfoArtworkDataHeight   | artworkDataHeight   |
| kMRMediaRemoteNowPlayingInfoAlbum               | album               |
| kMRMediaRemoteNowPlayingInfoTotalQueueCount     | totalQueueCount     | 
| kMRMediaRemoteNowPlayingInfoArtworkMIMEType     | artworkMIMEType     |
| kMRMediaRemoteNowPlayingInfoMediaType           | mediaType           |
| kMRMediaRemoteNowPlayingInfoDiscNumber          | discNumber          |
| kMRMediaRemoteNowPlayingInfoTimestamp           | timestamp           |
| kMRMediaRemoteNowPlayingInfoGenre               | genre               |
| kMRMediaRemoteNowPlayingInfoQueueIndex          | queueIndex          |
| kMRMediaRemoteNowPlayingInfoArtist              | artist              |
| kMRMediaRemoteNowPlayingInfoDefaultPlaybackRate | defaultPlaybackRate |
| kMRMediaRemoteNowPlayingInfoElapsedTime         | elapsedTime         |
| kMRMediaRemoteNowPlayingInfoTotalTrackCount     | totalTrackCount     |
| kMRMediaRemoteNowPlayingInfoIsMusicApp          | isMusicApp          |
| kMRMediaRemoteNowPlayingInfoUniqueIdentifier    | uniqueIdentifier    |
|                                                 |                     |
| -                                               | bundleIdentifier    |
| -                                               | displayName         |
| -                                               | isPlaying           |
| -                                               | volume              |
| -                                               | deviceID            |
| -                                               | deviceName          |

## Credits

- [kirtan-shah/nowplaying-cli](https://github.com/kirtan-shah/nowplaying-cli)
- GitHub Copilot
