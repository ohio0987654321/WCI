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

## Refactoring Project

The codebase is currently undergoing refactoring to improve maintainability and architecture. The following improvements have been implemented:

✅ **Enhanced Logging System** - Implemented a robust logging system with:
   - Categorized logging for better filtering
   - Support for multiple logging handlers
   - Direct formatting with source file and line information
   - Improved error reporting

The following refactoring tasks are still in progress:

1. Improving code organization
2. Reducing global state
3. Enhancing error handling
4. Modernizing method swizzling
5. Centralizing configuration
6. Better path resolution

See [refactoring.md](refactoring.md) for a detailed breakdown of all planned improvements.

## Recent Fixes

- **Fixed Segmentation Fault** - Resolved critical crash caused by infinite recursion in the logging compatibility layer
- **Improved Error Handling** - Enhanced error reporting for application launch issues
- **Removed Legacy Code** - Cleaned up obsolete code paths and backup files

## System-Level Limitations

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
