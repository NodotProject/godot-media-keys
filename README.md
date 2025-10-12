# Godot Media Keys

<p align="center">
    <img width="512" height="512" alt="image" src="https://github.com/NodotProject/godot-media-keys/blob/main/logo.png?raw=true" />
</p>

A cross-platform GDExtension for capturing global media key presses (Play/Pause, Next, Previous, Stop) in Godot 4 projects.

## Features

- **Cross-platform support**: Linux, Windows, and macOS
- **Global media key capture**: Works even when your game is in the background
- **Simple GDScript API**: Easy to integrate into your Godot projects
- **Native implementations**: Uses platform-specific APIs for optimal performance
  - **Linux**: D-Bus with MPRIS2 protocol + GNOME Settings Daemon signals
  - **Windows**: WM_APPCOMMAND message handling
  - **macOS**: CGEventTap for system-level event interception

## Installation

1. Copy the `addons/godot-media-keys` directory to your project's `addons/` folder
2. Enable the plugin in Project Settings → Plugins
3. The plugin will automatically register the `MediaKeys` singleton and autoload

## Usage

### Basic Example

```gdscript
extends Node

func _ready():
    # Get the MediaKeys singleton
    var media_keys = Engine.get_singleton("MediaKeys")

    # Connect to the media_key_pressed signal
    media_keys.media_key_pressed.connect(_on_media_key_pressed)

func _on_media_key_pressed(key: int):
    match key:
        MediaKeys.MEDIA_KEY_PLAY_PAUSE:
            print("Play/Pause pressed")
        MediaKeys.MEDIA_KEY_NEXT:
            print("Next pressed")
        MediaKeys.MEDIA_KEY_PREVIOUS:
            print("Previous pressed")
        MediaKeys.MEDIA_KEY_STOP:
            print("Stop pressed")
```

### Available Constants

- `MediaKeys.MEDIA_KEY_PLAY_PAUSE` - Play/Pause media key
- `MediaKeys.MEDIA_KEY_NEXT` - Next track media key
- `MediaKeys.MEDIA_KEY_PREVIOUS` - Previous track media key
- `MediaKeys.MEDIA_KEY_STOP` - Stop media key

### Signal

- `media_key_pressed(key: int)` - Emitted when a media key is pressed

## Platform-Specific Notes

### Linux
- Requires D-Bus session bus
- Registers as an MPRIS2 media player (`org.mpris.MediaPlayer2.godot`)
- Supports both MPRIS2 method calls and GNOME Settings Daemon signals
- Works automatically with most desktop environments

### Windows
- Uses a message-only window to receive WM_APPCOMMAND messages
- No special permissions required
- Works with standard keyboard media keys

### macOS
- **Requires Accessibility permissions** on first run
- System will prompt: "App wants to access Accessibility features"
- Grant permission in: System Preferences → Security & Privacy → Privacy → Accessibility
- Uses CGEventTap to intercept media key events
- Works with Apple keyboard media keys and compatible third-party keyboards

## Building from Source

### Prerequisites

- **All platforms**: Python 3.6+, SCons
- **Linux**: g++, libdbus-1-dev
- **Windows**: MinGW-w64 (for cross-compilation from Linux)
- **macOS**: Xcode command line tools

### Build Commands

```bash
# Build for current platform
./build_local.sh linux    # Linux
./build_local.sh windows  # Windows (cross-compile)
./build_local.sh macos    # macOS

# The compiled libraries will be placed in:
# addons/godot-media-keys/bin/
```

### Project Structure

```
godot-media-keys/
├── addons/godot-media-keys/
│   ├── bin/                        # Compiled libraries
│   ├── media_keys_autoload.gd      # Autoload script for polling
│   ├── media_keys_plugin.gd        # Plugin registration
│   └── plugin.cfg                  # Plugin metadata
├── src/
│   ├── media_keys.h                # Main header
│   ├── media_keys.cpp              # Cross-platform implementation
│   ├── media_keys_macos.mm         # macOS-specific code (Objective-C++)
│   └── register_types.cpp          # GDExtension registration
├── example/                        # Example scene
├── test/                           # Unit tests
├── SConstruct                      # Build configuration
└── build_local.sh                  # Build script
```

## Testing

Run the included unit tests using GUT (Godot Unit Testing):

```bash
./run_tests.sh
```

Or manually test using the example scene at `example/test_scene.tscn`.

## Architecture

- **MediaKeys** singleton: Inherits from `Object` and is registered via `Engine::register_singleton()`
- **Worker thread**: Each platform runs its own event-listening thread to avoid blocking the game
- **Event queue**: Thread-safe queue for passing events from worker thread to main thread
- **MediaKeysAutoload**: A Node-based autoload that polls events every frame and emits signals

This architecture ensures media key events are captured reliably without impacting game performance.

## Debug Logging

To enable debug logging during development:

1. Edit `SConstruct`
2. Uncomment: `env.Append(CPPDEFINES=['MEDIA_KEYS_DEBUG'])`
3. Rebuild the project

Debug messages will appear in Godot's output console.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Credits

This project was inspired by and uses reference implementations from:
- [SPMediaKeyTap](https://github.com/nevyn/SPMediaKeyTap) for macOS media key handling

## 💖 Support Me
Hi! I’m krazyjakee 🎮, creator and maintain­er of the *NodotProject* - a suite of open‑source Godot tools (e.g. Nodot, Gedis, GedisQueue etc) that empower game developers to build faster and maintain cleaner code.

I’m looking for sponsors to help sustain and grow the project: more dev time, better docs, more features, and deeper community support. Your support means more stable, polished tools used by indie makers and studios alike.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/krazyjakee)

Every contribution helps maintain and improve this project. And encourage me to make more projects like this!

*This is optional support. The tool remains free and open-source regardless.*

---

**Created with ❤️ for Godot Developers**  
For contributions, please open PRs on GitHub
