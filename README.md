# WindowControlInjector

A macOS utility that uses dylib injection to modify the behavior and appearance of target applications.

## Features

- **Screen Recording Protection**: Make application windows invisible to screen recording tools
- **UI Element Hiding**: Hide applications from Dock, status bar, and App Switcher
- **Focus Control**: Prevent windows from receiving keyboard focus
- **Click-Through Support**: Allow clicks to pass through windows
- **Custom Property Control**: Override specific NSWindow and NSApplication properties

## Usage

```
Usage: injector [options] <application-path>

Options:
  --invisible        Make windows invisible to screen recording
  --stealth          Hide application from Dock and status bar
  --unfocusable      Prevent windows from receiving focus
  --click-through    Make windows click-through (ignore mouse events)
  --all              Apply all profiles

  -v, --verbose      Enable verbose logging
  -h, --help         Show this help message
  --version          Show version information
```

### Examples

```bash
# Apply all profiles automatically (default behavior)
injector /Applications/TextEdit.app

# Make TextEdit invisible to screen recording only
injector --invisible /Applications/TextEdit.app

# Hide Calculator from the Dock and make it unfocusable
injector --stealth --unfocusable /Applications/Calculator.app
```

## Profiles

### Invisible Profile

Makes application windows invisible to screen recording and screenshots by setting the window's sharing type to `NSWindowSharingNone` and removing window shadows.

### Stealth Profile

Hides the application from the Dock, status bar, and App Switcher by modifying the application's activation policy and related properties.

### Unfocusable Profile

Prevents windows from receiving keyboard focus by setting `canBecomeKey` and `canBecomeMain` properties to `NO`.

### Click-Through Profile

Makes windows click-through, allowing mouse events to pass through to underlying windows by setting `ignoresMouseEvents` to `YES`.


## Building from Source

1. Clone the repository
2. Build with `make`
3. The built dylib and command-line tool will be in the `build` directory

## Requirements

- macOS 10.13 (High Sierra) or later
- Compatible with both Apple Silicon and Intel processors

## License

Copyright (c) 2025. All rights reserved.
