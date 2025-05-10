# WindowControlInjector

A macOS utility that uses dylib injection to modify the behavior and appearance of target applications.

## Features

- **Screen Recording Protection**: Make application windows invisible to screen recording tools
- **Dock Icon Hiding**: Hide applications from the macOS Dock
- **Always-on-Top Windows**: Keep windows above regular application windows
- **System UI Compatibility**: Properly interact with Mission Control and other system UI elements

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

WindowControlInjector applies multiple mechanisms automatically:

1. **Screen Recording Protection**
   - Sets window sharing type to `NSWindowSharingNone`
   - Applies immediately when the application launches

2. **Dock Icon Hiding**
   - Sets activation policy to `NSApplicationActivationPolicyAccessory`
   - Prevents the application icon from appearing in the Dock

3. **Always-on-Top Windows**
   - Sets window level to `NSFloatingWindowLevel`
   - Keeps windows above regular application windows

4. **System UI Integration**
   - Sets proper window collection behavior flags for Mission Control integration
   - Uses `NSWindowCollectionBehaviorParticipatesInCycle` to show windows in Mission Control
   - Uses `NSWindowStyleMaskNonactivatingPanel` to prevent focus stealing

All protections are applied automatically with a single command - no configuration required.

### System-Level Limitations

While WindowControlInjector provides powerful control over application windows, there are some system-level behaviors that are inherent to macOS:

- **Window focus behavior**: Windows use special styling (`NSWindowStyleMaskNonactivatingPanel`) to prevent stealing focus, but this may make them behave differently than standard application windows.

- **System UI interaction**: Although windows appear in Mission Control and interact properly with most system UI elements, some system-level operations may behave differently with modified windows.

- **Compatibility variations**: Some applications may respond differently to these modifications based on how they're built and which macOS frameworks they use.

These limitations exist because we're modifying application behavior at runtime rather than changing the applications themselves. The injector strikes a careful balance between functionality and system integration.

## Building from Source

1. Clone the repository
2. Build with `make`
3. The built dylib and command-line tool will be in the `build` directory

## Requirements

- macOS 10.13 (High Sierra) or later
- Compatible with both Apple Silicon and Intel processors

## License

Copyright (c) 2025. All rights reserved.
