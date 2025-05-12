/**
 * @file wc_window_scanner.m
 * @brief Implementation of the window scanner for periodic window protection
 */

#import "wc_window_scanner.h"
#import "wc_window_bridge.h"
#import "../util/logger.h"

@implementation WCWindowScanner {
    dispatch_source_t _timer;
    BOOL _isScanning;
    NSTimeInterval _currentInterval;
    BOOL _adaptiveScanning;
    NSDate *_lastScanTime;
    NSUInteger _lastWindowCount;

    // Variables for debounce handling
    BOOL _debounceEnabled;
    NSTimeInterval _debounceInterval;
    dispatch_source_t _debounceTimer;
    NSMutableArray<WCWindowInfo *> *_pendingProtectionWindows;

    // Application-specific configuration
    WCApplicationType _appType;
    NSArray<WCWindowInfo *> *_knownWindows;
    BOOL _isElectronApp;
    BOOL _isChromeApp;

    // Window tracking
    NSMutableSet<NSNumber *> *_protectedWindowIDs;
    NSDate *_lastProtectionAttemptTime;
}

#pragma mark - Lifecycle

+ (instancetype)sharedScanner {
    static WCWindowScanner *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _isScanning = NO;
        _timer = nil;
        _currentInterval = 1.0; // Default interval of 1 second
        _adaptiveScanning = YES; // Enable adaptive scanning by default
        _lastScanTime = nil;
        _lastWindowCount = 0;

        // Initialize debouncing
        _debounceEnabled = NO;
        _debounceInterval = 0.5; // Default to 500ms
        _debounceTimer = nil;
        _pendingProtectionWindows = [NSMutableArray array];

        // Initialize application-specific settings
        _appType = WCApplicationTypeUnknown;
        _knownWindows = @[];
        _isElectronApp = NO;
        _isChromeApp = NO;

        // Initialize window tracking
        _protectedWindowIDs = [NSMutableSet set];
        _lastProtectionAttemptTime = nil;
    }
    return self;
}

- (void)dealloc {
    [self stopScanning];
}

#pragma mark - Scanning Control

- (void)startScanningWithInterval:(NSTimeInterval)interval {
    if (_isScanning) {
        [self stopScanning];
    }

    _currentInterval = interval;

    // Create a timer using GCD
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

    uint64_t intervalNanoseconds = (uint64_t)(interval * NSEC_PER_SEC);
    dispatch_source_set_timer(_timer,
                             dispatch_time(DISPATCH_TIME_NOW, 0),
                             intervalNanoseconds,
                             intervalNanoseconds / 10);

    // Using a strong reference since the project uses manual reference counting
    typeof(self) selfRef = self;
    dispatch_source_set_event_handler(_timer, ^{
        [selfRef scanAndProtectWindows];

        // Adjust interval if adaptive scanning is enabled
        if (selfRef->_adaptiveScanning) {
            [selfRef adjustScanInterval];
        }
    });

    dispatch_resume(_timer);
    _isScanning = YES;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Started window scanning with interval: %.2f seconds", interval];
}

- (void)stopScanning {
    if (!_isScanning) return;

    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }

    _isScanning = NO;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Stopped window scanning"];
}

- (BOOL)isScanning {
    return _isScanning;
}

- (void)setAdaptiveScanning:(BOOL)adaptive {
    _adaptiveScanning = adaptive;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Adaptive scanning %@", adaptive ? @"enabled" : @"disabled"];
}

- (NSTimeInterval)currentScanInterval {
    return _currentInterval;
}

- (void)scanNow {
    [self scanAndProtectWindows];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Manual scan triggered"];
}

#pragma mark - Internal Methods

#pragma mark - Protection Configuration

- (void)setProtectionDebounce:(BOOL)debounceEnabled withInterval:(NSTimeInterval)interval {
    _debounceEnabled = debounceEnabled;
    _debounceInterval = interval;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Protection debouncing %@, interval: %.2f seconds",
                                         debounceEnabled ? @"enabled" : @"disabled", interval];

    // Cancel any existing debounce timer
    if (_debounceTimer) {
        dispatch_source_cancel(_debounceTimer);
        _debounceTimer = nil;
    }

    // Clear any pending operations
    [_pendingProtectionWindows removeAllObjects];
}

- (void)configureForApplicationType:(WCApplicationType)appType {
    _appType = appType;

    // Reset app-specific flags
    _isElectronApp = NO;
    _isChromeApp = NO;

    switch (appType) {
        case WCApplicationTypeElectron:
            // Use advanced multi-process handling for Electron apps
            [self enableAdvancedMultiProcessHandling:@{
                @"debounceInterval": @0.2,
                @"scanInterval": @0.7,
                @"aggressiveScanning": @YES
            }];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowScanner"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Configured for Electron app with multi-process handling"];
            break;

        case WCApplicationTypeChrome:
            _isChromeApp = YES;

            // Use advanced multi-process handling for Chrome with different settings
            [self enableAdvancedMultiProcessHandling:@{
                @"debounceInterval": @0.15,
                @"scanInterval": @0.5,
                @"aggressiveScanning": @YES
            }];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowScanner"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Configured for Chrome with multi-process handling"];
            break;

        default:
            // Default configuration for standard applications
            _currentInterval = 1.0;
            [self setProtectionDebounce:NO withInterval:0.5];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowScanner"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Configured for standard app with interval: %.2f seconds", _currentInterval];

            // Restart scanning with new configuration
            if (_isScanning) {
                [self stopScanning];
                [self startScanningWithInterval:_currentInterval];
            }
            break;
    }
}

- (void)enableAdvancedMultiProcessHandling:(NSDictionary *)options {
    // Default options
    NSTimeInterval debounceInterval = 0.3;
    BOOL aggressiveScanning = YES;
    NSTimeInterval scanInterval = 0.5;

    // Parse options if provided
    if (options) {
        NSNumber *debounceValue = options[@"debounceInterval"];
        if (debounceValue) {
            debounceInterval = [debounceValue doubleValue];
        }

        NSNumber *aggressiveScanningValue = options[@"aggressiveScanning"];
        if (aggressiveScanningValue) {
            aggressiveScanning = [aggressiveScanningValue boolValue];
        }

        NSNumber *scanIntervalValue = options[@"scanInterval"];
        if (scanIntervalValue) {
            scanInterval = [scanIntervalValue doubleValue];
        }
    }

    // Enable aggressive debouncing to prevent flickering
    [self setProtectionDebounce:YES withInterval:debounceInterval];

    // Set scanning interval for multi-process apps
    _currentInterval = scanInterval;

    // Mark this app for special handling
    _isElectronApp = YES;

    if (aggressiveScanning && _isScanning) {
        // Restart scanning with new settings
        [self stopScanning];
        [self startScanningWithInterval:_currentInterval];
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Enabled advanced multi-process handling with debounce: %.2fs, scan: %.2fs",
                                     debounceInterval, scanInterval];
}

#pragma mark - Protection Implementation

- (void)applyProtectionToWindows:(NSArray<WCWindowInfo *> *)windows {
    if (_debounceEnabled) {
        // Store windows for delayed protection
        [_pendingProtectionWindows addObjectsFromArray:windows];

        // If debounce timer is already running, let it handle these windows
        if (_debounceTimer) {
            return;
        }

        // Create a new debounce timer
        _debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

        uint64_t debounceIntervalNanoseconds = (uint64_t)(_debounceInterval * NSEC_PER_SEC);
        dispatch_source_set_timer(_debounceTimer,
                                 dispatch_time(DISPATCH_TIME_NOW, debounceIntervalNanoseconds),
                                 DISPATCH_TIME_FOREVER, // One-shot timer
                                 debounceIntervalNanoseconds / 10);

        typeof(self) selfRef = self;
        dispatch_source_set_event_handler(_debounceTimer, ^{
            [selfRef processDebouncedWindows];
        });

        dispatch_resume(_debounceTimer);
    } else {
        // No debounce, apply protection immediately
        for (WCWindowInfo *window in windows) {
            [self protectWindowWithoutFlickering:window];
        }
    }
}

- (void)processDebouncedWindows {
    // Apply protection to all pending windows
    for (WCWindowInfo *window in _pendingProtectionWindows) {
        [self protectWindowWithoutFlickering:window];
    }

    // Clear pending windows
    [_pendingProtectionWindows removeAllObjects];

    // Clean up timer
    if (_debounceTimer) {
        dispatch_source_cancel(_debounceTimer);
        _debounceTimer = nil;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"WindowScanner"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Processed debounced window protection"];
}

- (void)protectWindowWithoutFlickering:(WCWindowInfo *)window {
    // Check if we've already protected this window recently
    NSNumber *windowIDNumber = @(window.windowID);
    BOOL alreadyProtected = [_protectedWindowIDs containsObject:windowIDNumber];

    // Don't reapply protection too frequently to avoid flickering
    if (alreadyProtected && _lastProtectionAttemptTime) {
        NSTimeInterval timeSinceLastProtection = [[NSDate date] timeIntervalSinceDate:_lastProtectionAttemptTime];

        // If we protected this window very recently, skip to avoid flickering
        if (timeSinceLastProtection < 1.0) {
            return;
        }
    }

    // Apply screen recording protection
    BOOL screenProtectionSuccess = [window makeInvisibleToScreenRecording];

    // Set window to always on top (NSStatusWindowLevel is higher than NSFloatingWindowLevel)
    // NSStatusWindowLevel is 25, which makes the window appear above almost all other windows
    BOOL levelSuccess = [window setLevel:NSStatusWindowLevel];

    // Consider the operation successful if either protection method worked
    BOOL success = screenProtectionSuccess || levelSuccess;

    if (success) {
        // Record that we protected this window
        [_protectedWindowIDs addObject:windowIDNumber];

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Window protection applied - Screen: %@, Level: %@",
                                              screenProtectionSuccess ? @"Yes" : @"No",
                                              levelSuccess ? @"Yes" : @"No"];
    }
}

- (void)scanAndProtectWindows {
    @try {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"WindowScanner"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Scanning for windows to protect"];

        // Get the current PID
        pid_t currentPID = [[NSProcessInfo processInfo] processIdentifier];

        NSArray<WCWindowInfo *> *windows;
        NSArray<WCWindowInfo *> *newWindows = @[];

        // Use app-specific scanning technique if needed
        if (_isElectronApp) {
            // For Electron apps, use specialized window detection
            windows = [WCWindowBridge getAllWindowsForCurrentApplication];

            // Also check for delayed windows that were created after initial scan
            if (_knownWindows.count > 0) {
                newWindows = [WCWindowBridge findDelayedWindowsForPID:currentPID
                                                      excludingWindows:_knownWindows];

                if (newWindows.count > 0) {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                category:@"WindowScanner"
                                                    file:__FILE__
                                                    line:__LINE__
                                                function:__PRETTY_FUNCTION__
                                                  format:@"Found %lu new Electron windows to protect",
                                                        (unsigned long)newWindows.count];

                    // Add new windows to the list
                    NSMutableArray *allWindows = [NSMutableArray arrayWithArray:windows];
                    [allWindows addObjectsFromArray:newWindows];
                    windows = [allWindows copy];
                }
            }
        } else if (_isChromeApp) {
            // Chrome needs special process tracking due to its multi-process architecture
            NSArray<NSNumber *> *rendererPIDs = [WCWindowBridge getChromeRendererProcessesForMainPID:currentPID];

            NSMutableArray *allWindows = [NSMutableArray array];

            // Get windows for main Chrome process and all renderer processes
            NSArray<WCWindowInfo *> *mainProcessWindows = [WCWindowBridge getAllWindowsForPID:currentPID];
            [allWindows addObjectsFromArray:mainProcessWindows];

            // Get windows for each renderer process
            for (NSNumber *rendererPID in rendererPIDs) {
                NSArray<WCWindowInfo *> *rendererWindows = [WCWindowBridge getAllWindowsForPID:[rendererPID intValue]];
                [allWindows addObjectsFromArray:rendererWindows];
            }

            windows = [allWindows copy];
        } else {
            // Standard window scanning for normal apps
            windows = [WCWindowBridge getAllWindowsForCurrentApplication];
        }

        _lastWindowCount = windows.count;
        _knownWindows = windows; // Update known windows list

        // Use better protection mechanism to reduce flickering
        [self applyProtectionToWindows:windows];

        _lastScanTime = [NSDate date];
        _lastProtectionAttemptTime = [NSDate date];

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:@"WindowScanner"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Scan completed, found %lu windows (including %lu new windows)",
                                             (unsigned long)windows.count, (unsigned long)newWindows.count];
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowScanner"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception during window scanning: %@", exception.reason];
    }
}

- (void)adjustScanInterval {
    // Skip if we haven't scanned yet
    if (!_lastScanTime) return;

    // Calculate ideal scan interval based on window count
    NSTimeInterval newInterval;

    if (_lastWindowCount == 0) {
        // No windows, can scan less frequently
        newInterval = 2.0;
    } else if (_lastWindowCount < 5) {
        // Few windows, standard scanning
        newInterval = 1.0;
    } else if (_lastWindowCount < 15) {
        // More windows, increase frequency
        newInterval = 0.7;
    } else {
        // Many windows, scan more frequently
        newInterval = 0.5;
    }

    // Don't adjust if the change is minor
    if (fabs(newInterval - _currentInterval) < 0.2) return;

    // Only log if we're actually changing the interval
    if (newInterval != _currentInterval) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"WindowScanner"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Adjusting scan interval from %.2f to %.2f seconds based on %lu windows",
                                             _currentInterval, newInterval, (unsigned long)_lastWindowCount];
    }

    // Update the interval if it changed
    if (newInterval != _currentInterval) {
        // Save the new interval
        _currentInterval = newInterval;

        // Restart timer with new interval
        [self stopScanning];
        [self startScanningWithInterval:newInterval];
    }
}

@end
