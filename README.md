# WindowControlInjector

A macOS utility that uses dylib injection to modify the behavior and appearance of target applications.

## Features

- **Screen Recording Protection**: Make application windows invisible to screen recording tools
- **Dock Icon Hiding**: Hide applications from the macOS Dock
- **Status Bar Hiding**: Hide menu bar when the application has focus

## Usage

```
Usage: injector [options] <application-path>

Options:
  -v, --verbose      Enable verbose logging
  -h, --help         Show this help message
  --version          Show version information
```

### Examples

```bash
# Apply all protections (default behavior)
./build/injector /Applications/TextEdit.app

# With verbose logging
./build/injector -v /Applications/Calculator.app
```

## How It Works

WindowControlInjector applies multiple protection mechanisms automatically:

1. **Screen Recording Protection**
   - Sets window sharing type to `NSWindowSharingNone`
   - Applies immediately when the application launches

2. **Dock Icon Hiding**
   - Sets activation policy to `NSApplicationActivationPolicyAccessory`
   - Prevents the application icon from appearing in the Dock

3. **Menu Bar Hiding**
   - Applies `NSApplicationPresentationHideMenuBar` presentation options
   - Hides the menu bar when the application has focus

All protections are applied automatically with a single command - no configuration required.

### System-Level Limitations

While WindowControlInjector can effectively hide an application from screenshots, the Dock, and the status bar, there are some visual cues that are unavoidable at the macOS system level:

- **Window focus indicators**: When a protected application has keyboard focus, other applications' title bars will still change to an inactive color state. This happens because macOS needs to track which application has input focus for keyboard events, and it signals this change to all applications.

- **Menu bar changes**: The system menu bar may still show subtle changes when a protected application has focus, though the application's menu items will be hidden.

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
