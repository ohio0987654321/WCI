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

Makes application windows invisible to screen recording and screenshots by:
- Setting the window's sharing type to `NSWindowSharingNone`
- Configuring the window's collection behavior to exclude from window lists and screenshots
- Making the window non-opaque and setting transparent background
- Removing window shadows
- Making the titlebar transparent for better stealth

### Stealth Profile

Hides the application from the Dock, status bar, and App Switcher by:
- Modifying the application's activation policy to `NSApplicationActivationPolicyAccessory`
- Setting presentation options to hide the Dock and menu bar
- Preventing application activation through typical OS X means
- Configuring windows to be excluded from window menus and lists
- Setting special collection behavior to keep windows out of standard window management
- Allowing windows to be hidden and making titlebar transparent
- Setting window level below normal to prevent accidental focus

### Unfocusable Profile

Prevents windows from receiving keyboard focus by:
- Setting `canBecomeKey` and `canBecomeMain` properties to `NO`
- Configuring collection behavior to prevent window from being included in focus cycles
- Excluding windows from window menus and keyboard-based window selection
- Preventing interaction with window backgrounds
- Visually styling windows to appear unfocused with transparent titlebar
- Setting application activity state to prevent focus

### Click-Through Profile

Makes windows click-through, allowing mouse events to pass through to underlying windows by:
- Setting `ignoresMouseEvents` to `YES`
- Making the window visually indicate its click-through status with transparency
- Setting collection behavior to mark the window as transient and stationary
- Removing window shadows to better indicate non-interactive nature
- Ensuring the window stays visible but unfocusable with a transparent titlebar
- Allowing repositioning via window background if needed


## Building from Source

1. Clone the repository
2. Build with `make`
3. The built dylib and command-line tool will be in the `build` directory

## Requirements

- macOS 10.13 (High Sierra) or later
- Compatible with both Apple Silicon and Intel processors

## License

Copyright (c) 2025. All rights reserved.
