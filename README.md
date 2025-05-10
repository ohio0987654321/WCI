# WindowControlInjector

A macOS utility that uses dylib injection to modify the behavior and appearance of target applications.

## Features

- **Screen Recording Protection**: Make application windows invisible to screen recording tools
- **Dock Icon Hiding**: Hide applications from the macOS Dock
- **Status Bar Hiding**: Hide menu bar when the application has focus

## Usage

```
Usage: ./build/injector [options] <application-path>

Options:
  --core             Core functionality (screen recording protection, dock/status bar hiding) [DEFAULT]
  --invisible        Make windows invisible to screen recording
  --stealth          Hide application from Dock and status bar
  --direct-control   Enhanced control using direct Objective-C messaging
  --all              Apply all profiles

Window interaction control:
  --enable-interaction  Allow windows to receive keyboard focus (while maintaining protection)
  --disable-interaction Prevent windows from receiving keyboard focus

  -v, --verbose      Enable verbose logging
  -h, --help         Show this help message
  --version          Show version information
```

**Default Behavior**: Running the injector with just an application path will apply the `core` profile, providing essential protection without unnecessary visual effects.

### Examples

```bash
# Apply core profile (default behavior)
./build/injector /Applications/TextEdit.app

# Make TextEdit invisible to screen recording only
./build/injector --invisible /Applications/TextEdit.app

# Hide Calculator from the Dock
./build/injector --stealth /Applications/Calculator.app

# Use the core profile explicitly
./build/injector --core /Applications/Safari.app

# Use enhanced protection with direct-control
./build/injector --direct-control /Applications/Terminal.app
```

## Profiles

### Core Profile

Implements the essential functionality needed for privacy and discretion:
- Screen recording protection by setting the window's sharing type to `NSWindowSharingNone`
- Dock icon hiding by using accessory activation policy
- Status bar hiding when the application has focus

This profile focuses only on the necessary features without any additional visual effects or behavioral modifications.

### Other Available Profiles

For advanced use cases, additional profiles are available:

#### Invisible Profile
- Makes windows invisible to screen recording with `NSWindowSharingNone`

#### Stealth Profile
- Hides application from Dock with `NSApplicationActivationPolicyAccessory`
- Hides menu bar with presentation options


#### Direct Control Profile
- Advanced window control using direct Objective-C messaging
- Provides stronger screen recording protection for complex applications

### System-Level Limitations

While WindowControlInjector can effectively hide an application from screenshots, the Dock, and the status bar, there are some visual cues that are unavoidable at the macOS system level:

- **Window focus indicators**: When a protected application has keyboard focus, other applications' title bars will still change to an inactive color state. This happens because macOS needs to track which application has input focus for keyboard events, and it signals this change to all applications.

- **Menu bar changes**: Depending on the protection profiles used, the system menu bar may still show the protected application's menu items when it has focus.

These limitations exist because they are fundamental to how macOS manages application focus and cannot be completely overridden without modifying core system components.

## Building from Source

1. Clone the repository
2. Build with `make`
3. The built dylib and command-line tool will be in the `build` directory

## Requirements

- macOS 10.13 (High Sierra) or later
- Compatible with both Apple Silicon and Intel processors

## License

Copyright (c) 2025. All rights reserved.
