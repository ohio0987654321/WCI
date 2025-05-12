/**
 * @file wc_window_bridge.m
 * @brief Implementation of unified window detection
 */

#import "wc_window_bridge.h"
#import "../util/logger.h"
#import <AppKit/AppKit.h>

@implementation WCWindowBridge

// Keep track of detected application types
static NSMutableDictionary<NSString *, NSNumber *> *applicationTypes;

// Application type patterns for detection
static NSArray<NSDictionary *> *applicationPatterns;

// Standard Objective-C runtime initialize method
+ (void)initialize {
    if (self == [WCWindowBridge class]) {
        applicationTypes = [NSMutableDictionary dictionary];

        // Initialize application patterns
        applicationPatterns = @[
            @{
                @"type": @(WCApplicationTypeElectron),
                @"bundleIdPatterns": @[@"com.electron.", @"org.electron.", @"com.github.electron"],
                @"namePatterns": @[@"electron", @"Slack", @"VS Code", @"Visual Studio Code", @"Microsoft Teams", @"Atom", @"WhatsApp"],
                @"frameworkPaths": @[@"Contents/Frameworks/Electron Framework.framework"]
            },
            @{
                @"type": @(WCApplicationTypeChrome),
                @"bundleIdPatterns": @[@"com.google.Chrome", @"org.chromium."],
                @"namePatterns": @[@"Google Chrome", @"Chromium", @"Chrome"],
                @"executableNamePatterns": @[@"Chrome", @"Chromium"]
            }
        ];
    }
}

// Custom initialization method called from WCInitialize
+ (void)setupWindowBridge {
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Initializing WCWindowBridge subsystem"];

    // Ensure dictionary is initialized
    if (!applicationTypes) {
        applicationTypes = [NSMutableDictionary dictionary];
    }
}

#pragma mark - Window Detection

+ (NSArray<WCWindowInfo *> *)getAllWindowsForCurrentApplication {
    NSMutableArray<WCWindowInfo *> *allWindows = [NSMutableArray array];

    // 1. Get windows using AppKit API
    NSArray<NSWindow *> *appKitWindows = [NSApp windows];
    for (NSWindow *window in appKitWindows) {
        WCWindowInfo *windowInfo = [[WCWindowInfo alloc] initWithNSWindow:window];
        if (windowInfo) {
            [allWindows addObject:windowInfo];
        }
    }

    // 2. Get windows using CoreGraphics API for the current process ID
    pid_t currentPID = [[NSProcessInfo processInfo] processIdentifier];
    NSArray<WCWindowInfo *> *cgWindows = [self getWindowsForPID:currentPID];

    // Merge the lists, avoiding duplicates
    for (WCWindowInfo *cgWindow in cgWindows) {
        BOOL isDuplicate = NO;

        for (WCWindowInfo *existingWindow in allWindows) {
            if (existingWindow.windowID == cgWindow.windowID) {
                isDuplicate = YES;
                break;
            }
        }

        if (!isDuplicate) {
            [allWindows addObject:cgWindow];
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Found %lu windows for current application", (unsigned long)allWindows.count];

    return [allWindows copy];
}

+ (NSArray<WCWindowInfo *> *)getAllWindowsForPID:(pid_t)pid {
    NSMutableArray<WCWindowInfo *> *allWindows = [NSMutableArray array];

    // Get windows for the main process
    NSArray<WCWindowInfo *> *mainProcessWindows = [self getWindowsForPID:pid];
    [allWindows addObjectsFromArray:mainProcessWindows];

    // Get child process IDs
    NSArray<NSNumber *> *childPIDs = [self getChildProcessesForPID:pid];

    // Get windows for each child process
    for (NSNumber *childPID in childPIDs) {
        NSArray<WCWindowInfo *> *childWindows = [self getWindowsForPID:[childPID intValue]];
        [allWindows addObjectsFromArray:childWindows];
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Found %lu windows for PID %d (including %lu child processes)",
                                         (unsigned long)allWindows.count, (int)pid, (unsigned long)childPIDs.count];

    return [allWindows copy];
}

+ (NSArray<WCWindowInfo *> *)getAllWindowsForApplicationWithPath:(NSString *)path {
    if (!path || [path length] == 0) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowBridge"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot get windows for empty application path"];
        return @[];
    }

    // Find the application by path
    NSRunningApplication *app = nil;
    NSArray<NSRunningApplication *> *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];

    for (NSRunningApplication *runningApp in runningApps) {
        NSURL *bundleURL = [runningApp bundleURL];
        if ([[bundleURL path] isEqualToString:path]) {
            app = runningApp;
            break;
        }
    }

    if (!app) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"WindowBridge"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Application not found at path: %@", path];
        return @[];
    }

    // Get windows for the application's process
    pid_t appPID = [app processIdentifier];
    return [self getAllWindowsForPID:appPID];
}

+ (NSArray<WCWindowInfo *> *)getWindowsForPID:(pid_t)pid {
    NSMutableArray<WCWindowInfo *> *windows = [NSMutableArray array];

    // Get all windows using CoreGraphics
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionAll, kCGNullWindowID);

    if (windowList) {
        CFIndex count = CFArrayGetCount(windowList);

        for (CFIndex i = 0; i < count; i++) {
            NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, i);

            // Check if this window belongs to the specified process
            NSNumber *windowPID = windowInfo[(NSString *)kCGWindowOwnerPID];
            if (windowPID && [windowPID intValue] == pid) {
                WCWindowInfo *window = [[WCWindowInfo alloc] initWithCGWindowInfo:windowInfo];
                if (window) {
                    [windows addObject:window];
                }
            }
        }

        CFRelease(windowList);
    }

    return [windows copy];
}

#pragma mark - Process Management

+ (NSArray<NSNumber *> *)getChildProcessesForPID:(pid_t)pid {
    NSMutableArray<NSNumber *> *childPIDs = [NSMutableArray array];

    // Use ps command to get child processes
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/ps"];
    [task setArguments:@[@"-eo", @"ppid,pid"]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    NSFileHandle *file = [pipe fileHandleForReading];

    @try {
        [task launch];
        [task waitUntilExit];

        if ([task terminationStatus] != 0) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"WindowBridge"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to get child processes for PID: %d", (int)pid];
            return @[];
        }

        NSData *data = [file readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        // Parse the output - format is:
        // PPID  PID
        // ...
        NSArray<NSString *> *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        for (NSString *line in lines) {
            // Skip header line
            if ([line hasPrefix:@"PPID"] || [line length] == 0) {
                continue;
            }

            NSArray<NSString *> *parts = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];

            if (parts.count >= 2) {
                NSInteger ppid = [parts[0] integerValue];

                if (ppid == pid) {
                    NSInteger childPID = [parts[1] integerValue];
                    [childPIDs addObject:@(childPID)];
                }
            }
        }
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowBridge"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception while getting child processes: %@", exception.reason];
    }

    return [childPIDs copy];
}

#pragma mark - Window Management

+ (BOOL)protectAllWindowsForPID:(pid_t)pid {
    NSArray<WCWindowInfo *> *windows = [self getAllWindowsForPID:pid];

    if (windows.count == 0) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"WindowBridge"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"No windows found to protect for PID: %d", (int)pid];
        return NO;
    }

    BOOL allSucceeded = YES;

    for (WCWindowInfo *window in windows) {
        // Make window invisible to screen recording
        BOOL success = [window makeInvisibleToScreenRecording];

        // Set proper window level for Mission Control visibility
        BOOL levelSuccess = [window setLevel:NSNormalWindowLevel]; // This will use the NSNormalWindowLevel internally

        // Disable status bar
        if ([window respondsToSelector:@selector(disableStatusBar)]) {
            [window disableStatusBar];
        }

        if (!success || !levelSuccess) {
            allSucceeded = NO;
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowBridge"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to fully protect window %@ for PID: %d",
                                                 window, (int)pid];
        }
    }

    [[WCLogger sharedLogger] logWithLevel:allSucceeded ? WCLogLevelInfo : WCLogLevelWarning
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Protected %lu/%lu windows for PID: %d with Mission Control visibility and disabled status bars",
                                         (unsigned long)(allSucceeded ? windows.count : windows.count - 1),
                                         (unsigned long)windows.count,
                                         (int)pid];

    return allSucceeded;
}

+ (BOOL)setLevelForAllWindowsForPID:(pid_t)pid level:(NSWindowLevel)level {
    NSArray<WCWindowInfo *> *windows = [self getAllWindowsForPID:pid];

    if (windows.count == 0) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"WindowBridge"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"No windows found to set level for PID: %d", (int)pid];
        return NO;
    }

    BOOL allSucceeded = YES;

    for (WCWindowInfo *window in windows) {
        // Note: Our improved setLevel implementation will always use NSNormalWindowLevel
        // for Mission Control compatibility and apply proper CGS window tags
        BOOL success = [window setLevel:level];

        // Also disable status bar for all windows
        if ([window respondsToSelector:@selector(disableStatusBar)]) {
            [window disableStatusBar];
        }

        if (!success) {
            allSucceeded = NO;
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowBridge"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to set level for window %@ for PID: %d",
                                                 window, (int)pid];
        }
    }

    [[WCLogger sharedLogger] logWithLevel:allSucceeded ? WCLogLevelInfo : WCLogLevelWarning
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Set level to %ld (using NSNormalWindowLevel internally) for %lu/%lu windows for PID: %d with Mission Control visibility",
                                         (long)level,
                                         (unsigned long)(allSucceeded ? windows.count : windows.count - 1),
                                         (unsigned long)windows.count,
                                         (int)pid];

    return allSucceeded;
}

#pragma mark - Application Type Detection

+ (WCApplicationType)detectApplicationTypeForPath:(NSString *)bundlePath {
    // Check if we've already determined the type for this app
    if (applicationTypes[bundlePath]) {
        return (WCApplicationType)[applicationTypes[bundlePath] unsignedIntegerValue];
    }

    WCApplicationType appType = WCApplicationTypeStandard;

    // Load the app's Info.plist to check for identifiers
    NSString *infoPlistPath = [bundlePath stringByAppendingPathComponent:@"Contents/Info.plist"];
    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];

    if (infoPlist) {
        NSString *bundleID = infoPlist[@"CFBundleIdentifier"];
        NSString *executableName = infoPlist[@"CFBundleExecutable"];
        NSString *appName = infoPlist[@"CFBundleName"];

        // Use our pattern-based detection system
        for (NSDictionary *pattern in applicationPatterns) {
            // Get the application type associated with this pattern
            NSNumber *typeNumber = pattern[@"type"];
            if (!typeNumber) continue;

            // Check bundle ID patterns
            NSArray *bundleIdPatterns = pattern[@"bundleIdPatterns"];
            if (bundleIdPatterns && bundleID) {
                for (NSString *bundlePattern in bundleIdPatterns) {
                    if ([bundleID rangeOfString:bundlePattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        appType = [typeNumber unsignedIntegerValue];
                        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                     category:@"WindowBridge"
                                                         file:__FILE__
                                                         line:__LINE__
                                                     function:__PRETTY_FUNCTION__
                                                       format:@"Detected app type %lu by bundle ID pattern: %@",
                                                             (unsigned long)appType, bundlePattern];
                        goto patternFound;
                    }
                }
            }

            // Check app name patterns
            NSArray *namePatterns = pattern[@"namePatterns"];
            if (namePatterns && (appName || executableName)) {
                NSString *nameToCheck = appName ? appName : executableName;
                for (NSString *namePattern in namePatterns) {
                    if ([nameToCheck rangeOfString:namePattern options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [bundlePath rangeOfString:namePattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        appType = [typeNumber unsignedIntegerValue];
                        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                     category:@"WindowBridge"
                                                         file:__FILE__
                                                         line:__LINE__
                                                     function:__PRETTY_FUNCTION__
                                                       format:@"Detected app type %lu by name pattern: %@",
                                                             (unsigned long)appType, namePattern];
                        goto patternFound;
                    }
                }
            }

            // Check executable name patterns
            NSArray *executablePatterns = pattern[@"executableNamePatterns"];
            if (executablePatterns && executableName) {
                for (NSString *execPattern in executablePatterns) {
                    if ([executableName rangeOfString:execPattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        appType = [typeNumber unsignedIntegerValue];
                        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                     category:@"WindowBridge"
                                                         file:__FILE__
                                                         line:__LINE__
                                                     function:__PRETTY_FUNCTION__
                                                       format:@"Detected app type %lu by executable pattern: %@",
                                                             (unsigned long)appType, execPattern];
                        goto patternFound;
                    }
                }
            }

            // Check framework paths
            NSArray *frameworkPaths = pattern[@"frameworkPaths"];
            if (frameworkPaths) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                for (NSString *frameworkPath in frameworkPaths) {
                    NSString *fullPath = [bundlePath stringByAppendingPathComponent:frameworkPath];
                    if ([fileManager fileExistsAtPath:fullPath]) {
                        appType = [typeNumber unsignedIntegerValue];
                        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                     category:@"WindowBridge"
                                                         file:__FILE__
                                                         line:__LINE__
                                                     function:__PRETTY_FUNCTION__
                                                       format:@"Detected app type %lu by framework path: %@",
                                                             (unsigned long)appType, frameworkPath];
                        goto patternFound;
                    }
                }
            }
        }
    }

patternFound:
    // Cache the detected type
    applicationTypes[bundlePath] = @(appType);

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Final application type detected for %@: %lu",
                                         bundlePath, (unsigned long)appType];

    return appType;
}

+ (NSArray<NSNumber *> *)getElectronRendererProcessesForMainPID:(pid_t)mainPID {
    NSMutableArray<NSNumber *> *rendererPIDs = [NSMutableArray array];
    NSArray<NSNumber *> *childPIDs = [self getChildProcessesForPID:mainPID];

    // First level of child processes from main Electron process
    for (NSNumber *childPID in childPIDs) {
        pid_t pid = [childPID intValue];

        // We need to check if this is a renderer process by checking process name
        NSString *processName = [self getProcessNameForPID:pid];

        // Electron renderer processes often have "Renderer" or "Helper" in their name
        if ([processName containsString:@"Renderer"] ||
            [processName containsString:@"Helper"] ||
            [processName containsString:@"electron"]) {
            [rendererPIDs addObject:childPID];

            // Also get any grandchild processes of detected renderer
            NSArray<NSNumber *> *grandchildPIDs = [self getChildProcessesForPID:pid];
            [rendererPIDs addObjectsFromArray:grandchildPIDs];
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Found %lu Electron renderer processes for main PID: %d",
                                         (unsigned long)rendererPIDs.count, (int)mainPID];

    return [rendererPIDs copy];
}

+ (NSArray<NSNumber *> *)getChromeRendererProcessesForMainPID:(pid_t)mainPID {
    NSMutableArray<NSNumber *> *rendererPIDs = [NSMutableArray array];
    NSArray<NSNumber *> *childPIDs = [self getChildProcessesForPID:mainPID];

    // Chrome has a more complex process structure with multiple helpers
    for (NSNumber *childPID in childPIDs) {
        pid_t pid = [childPID intValue];

        // Check process name
        NSString *processName = [self getProcessNameForPID:pid];

        // Chrome renderer processes usually have "Helper" in their name
        if ([processName containsString:@"Helper"]) {
            [rendererPIDs addObject:childPID];

            // Add grandchildren - Chrome has multiple levels of helper processes
            NSArray<NSNumber *> *grandchildPIDs = [self getChildProcessesForPID:pid];
            [rendererPIDs addObjectsFromArray:grandchildPIDs];

            // Chrome can have even deeper process trees, so add great-grandchildren
            for (NSNumber *grandchildPID in grandchildPIDs) {
                NSArray<NSNumber *> *greatGrandchildPIDs = [self getChildProcessesForPID:[grandchildPID intValue]];
                [rendererPIDs addObjectsFromArray:greatGrandchildPIDs];
            }
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Found %lu Chrome renderer processes for main PID: %d",
                                         (unsigned long)rendererPIDs.count, (int)mainPID];

    return [rendererPIDs copy];
}

+ (NSString *)getProcessNameForPID:(pid_t)pid {
    NSString *processName = @"";

    // Use ps command to get process name
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/ps"];
    [task setArguments:@[@"-p", [NSString stringWithFormat:@"%d", pid], @"-o", @"command="]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    NSFileHandle *file = [pipe fileHandleForReading];

    @try {
        [task launch];
        [task waitUntilExit];

        if ([task terminationStatus] == 0) {
            NSData *data = [file readDataToEndOfFile];
            processName = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            processName = [processName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowBridge"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception while getting process name: %@", exception.reason];
    }

    return processName;
}

+ (NSArray<WCWindowInfo *> *)findDelayedWindowsForPID:(pid_t)pid excludingWindows:(NSArray<WCWindowInfo *> *)existingWindows {
    NSMutableArray<WCWindowInfo *> *newWindows = [NSMutableArray array];

    // Get all current windows for the PID
    NSArray<WCWindowInfo *> *currentWindows = [self getWindowsForPID:pid];

    // Also check child processes based on application type
    NSString *appPath = [self getApplicationPathForPID:pid];
    WCApplicationType appType = [self detectApplicationTypeForPath:appPath];

    NSArray<NSNumber *> *childPIDs = @[];

    if (appType == WCApplicationTypeElectron) {
        childPIDs = [self getElectronRendererProcessesForMainPID:pid];
    } else if (appType == WCApplicationTypeChrome) {
        childPIDs = [self getChromeRendererProcessesForMainPID:pid];
    } else {
        childPIDs = [self getChildProcessesForPID:pid];
    }

    // Check windows for each child process
    for (NSNumber *childPID in childPIDs) {
        NSArray<WCWindowInfo *> *childWindows = [self getWindowsForPID:[childPID intValue]];
        currentWindows = [currentWindows arrayByAddingObjectsFromArray:childWindows];
    }

    // Find windows that weren't in the existing windows list
    for (WCWindowInfo *window in currentWindows) {
        BOOL isNewWindow = YES;

        for (WCWindowInfo *existingWindow in existingWindows) {
            if (existingWindow.windowID == window.windowID) {
                isNewWindow = NO;
                break;
            }
        }

        if (isNewWindow) {
            [newWindows addObject:window];
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowBridge"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Found %lu delayed windows for PID: %d",
                                         (unsigned long)newWindows.count, (int)pid];

    return [newWindows copy];
}

+ (NSString *)getApplicationPathForPID:(pid_t)pid {
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    return [[app bundleURL] path];
}

@end
