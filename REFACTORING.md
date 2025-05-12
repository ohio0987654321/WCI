Refactoring Document for WindowControlInjector
Introduction
The WindowControlInjector project is a macOS utility that uses DYLIB injection to modify the behavior and appearance of application windows at runtime. Its current features include screen recording protection, Dock icon hiding, always-on-top windows, and system UI compatibility. However, the existing implementation struggles with non-AppKit applications (e.g., Google Chrome, Discord, Electron-based apps) due to its reliance on AppKit-specific mechanisms. Additionally, the codebase suffers from poor maintainability, excessive global state, and outdated techniques.
This refactoring aims to:

Ensure compatibility with both AppKit and non-AppKit applications by integrating the Core Graphics Services (CGS) API.
Improve code maintainability and reliability through better organization, error handling, and modern practices.
Achieve consistent screen recording bypass across all target applications.

Architecture Changes
1. Integration of CGS API
The CGS API, a low-level interface to the macOS Window Server, will replace AppKit-specific calls for screen recording protection. Key benefits include:

Universal Compatibility: Controls windows across all app types, bypassing AppKit limitations.
Screen Recording Bypass: Uses CGSSetWindowSharingState to prevent window capture, effective for both AppKit and non-AppKit apps.
Dynamic Resolution: Functions will be resolved at runtime via dlsym to mitigate risks from undocumented API changes.

2. Unified Window Detection
A dual-detection approach will ensure all windows are identified:

AppKit Apps: Use [NSApp windows] for traditional macOS applications.
Non-AppKit Apps: Use CGWindowListCopyWindowInfo with PID filtering to detect windows in apps like Chrome.

This ensures robust window management across diverse application architectures.
3. Optimized DYLIB Injection
DYLIB injection will be refined to:

Operate within target processes for direct window access.
Support multi-process apps (e.g., Chrome) with improved stability.

Implementation Details
1. Screen Recording Protection

CGS API Usage: Apply CGSSetWindowSharingState to set windows to a non-recordable state.
Fallback: Retain NSWindowSharingNone for AppKit apps as a secondary mechanism.
Dynamic Application: Protection will be applied to newly created windows via periodic scans (e.g., every 0.5 seconds).

2. Window Detection Logic

Bridge Class: Introduce WCWindowBridge to abstract detection:
AppKit: Query [NSApp windows].
Non-AppKit: Filter CGWindowListCopyWindowInfo by target PID.


Real-Time Updates: Monitor window creation to apply protections instantly.

3. Error Handling and Logging

Error Handling: Add checks for injection failures, API resolution errors, and protection application, with fallback behaviors.
Logging: Enhance with categorized logs (debug, info, error) including window IDs and process details.

4. Code Cleanup

Modular Design: Split into modules (e.g., injection, detection, protection).
State Management: Reduce global variables, favoring dependency injection.
Modern Practices: Replace legacy swizzling with safer alternatives (e.g., method_exchangeImplementations).

Future Challenges

CGS API Stability: Monitor macOS updates for potential API changes.
Multi-Process Support: Refine handling of apps with dynamic process spawning.
Configuration: Plan for user-customizable protection options.

Conclusion
This refactoring leverages the CGS API to deliver a robust, maintainable WindowControlInjector capable of bypassing screen recording for all macOS applications. The updated architecture and implementation ensure long-term scalability and reliability.
