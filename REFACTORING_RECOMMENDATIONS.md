# WindowControlInjector Refactoring Recommendations

Based on the analysis of the WindowControlInjector codebase, the following refactoring recommendations have been identified to improve code quality, maintainability, and reduce technical debt.

## Non-existent Files

1. **`wc_multi_process_adapter.h`**: This file appears in the VSCode tabs but actually doesn't exist in the file system. It should be cleaned up from version control.

## Unused Code Removal

1. Review the codebase for any unused methods or classes that can be safely removed:
   - Check for methods that are declared but never called
   - Look for deprecated code paths that have been replaced but not removed
   - Remove any commented-out code that's no longer needed

## Code Duplication

1. Identify instances of duplicated code that can be refactored into shared utilities:
   - Window scanning logic in `wc_window_scanner.m` contains some duplicated code paths
   - Error handling patterns are repeated across multiple files

## Redundant or Overlapping Functionality

1. Merge or streamline overlapping functionality:
   - The relationship between window scanning and window protection should be clarified
   - Process detection utilities could be consolidated into a dedicated utility class

## Architectural Improvements

1. Consider extracting process management utilities from `WCWindowBridge` into a dedicated `WCProcessManager` class
2. The window protection mechanism in `WCWindowInfo` and `WCWindowBridge` has some overlapping responsibilities

## Implementation Plan

The following steps should be taken to implement these refactoring recommendations:

1. Remove references to the non-existent `wc_multi_process_adapter.h` file from version control and IDE settings.

2. Create a dedicated process management class:
   ```objc
   @interface WCProcessManager : NSObject

   + (NSArray<NSNumber *> *)getChildProcessesForPID:(pid_t)pid;
   + (NSString *)getProcessNameForPID:(pid_t)pid;
   + (NSArray<NSNumber *> *)getElectronRendererProcessesForMainPID:(pid_t)mainPID;
   + (NSArray<NSNumber *> *)getChromeRendererProcessesForMainPID:(pid_t)mainPID;

   @end
   ```

3. Refactor window scanning logic to remove duplication:
   - Extract common window detection patterns
   - Improve error handling and logging consistency

4. Implement status bar hiding consistently across window types:
   - Ensure the `disableStatusBar` method is properly implemented for all window types
   - Add proper fallbacks when direct APIs aren't available

## Status Bar Hiding Implementation

The `disableStatusBar` method in `WCWindowInfo` should be implemented consistently for both AppKit and non-AppKit windows. For AppKit windows, this can use standard APIs, while for non-AppKit windows, CGS APIs should be used.

## Testing Recommendations

After implementing these changes, thorough testing should be conducted with:

1. Standard AppKit applications
2. Electron-based applications (VS Code, Slack, etc.)
3. Chromium-based applications (Chrome, Edge, etc.)
4. Applications with complex window hierarchies

Focus testing on:
- Window protection functionality
- Status bar visibility
- Performance with multiple windows
- Application startup behavior

## Conclusion

These refactoring recommendations aim to improve code quality, reduce duplication, and ensure consistent behavior across different application types. The biggest improvements will come from clarifying architectural boundaries, removing non-existent file references, and implementing consistent status bar handling.
