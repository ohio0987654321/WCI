/**
 * @file wc_window_info.m
 * @brief Implementation of window information abstraction
 */

#import "wc_window_info.h"
#import "../util/wc_cgs_functions.h"
#import "../util/logger.h"
#import <AppKit/AppKit.h>

@implementation WCWindowInfo {
    // Private instance variables
    CGWindowID _windowID;
    NSWindow * _nsWindow;
    CGRect _frame;
    NSString *_title;
    pid_t _ownerPID;
    NSString *_ownerName;
    BOOL _isOnScreen;
    NSWindowLevel _level;
    CGSWindowSharingType _sharingType;
    BOOL _isProtected;

    // Flags to track what information has been loaded
    BOOL _didLoadBasicInfo;
    BOOL _didLoadExtendedInfo;
    BOOL _didCheckProtection;
}

#pragma mark - Initialization

- (instancetype)initWithWindowID:(CGWindowID)windowID {
    if (self = [super init]) {
        _windowID = windowID;
        _nsWindow = nil;
        _didLoadBasicInfo = NO;
        _didLoadExtendedInfo = NO;
        _didCheckProtection = NO;

        // Try to find the NSWindow instance for this window ID
        for (NSWindow *window in [NSApp windows]) {
            if ((CGWindowID)[window windowNumber] == windowID) {
                _nsWindow = window;
                break;
            }
        }

        // Load basic window information
        [self loadBasicWindowInfo];
    }
    return self;
}

- (instancetype)initWithNSWindow:(NSWindow *)window {
    if (self = [super init]) {
        if (!window) {
            return nil;
        }

        _nsWindow = window;
        _windowID = (CGWindowID)[window windowNumber];
        _didLoadBasicInfo = NO;
        _didLoadExtendedInfo = NO;
        _didCheckProtection = NO;

        // Load basic window information
        [self loadBasicWindowInfo];
    }
    return self;
}

- (instancetype)initWithCGWindowInfo:(NSDictionary *)windowInfo {
    if (self = [super init]) {
        if (!windowInfo) {
            return nil;
        }

        // Extract window ID
        NSNumber *windowIDNum = windowInfo[(NSString *)kCGWindowNumber];
        if (!windowIDNum) {
            return nil;
        }

        _windowID = [windowIDNum unsignedIntValue];
        _nsWindow = nil;
        _didLoadBasicInfo = YES;  // Info is loaded from the dictionary
        _didLoadExtendedInfo = YES;
        _didCheckProtection = NO;

        // Extract window information from the dictionary
        _title = windowInfo[(NSString *)kCGWindowName];
        if (!_title) _title = @"";

        NSNumber *ownerPIDNum = windowInfo[(NSString *)kCGWindowOwnerPID];
        _ownerPID = ownerPIDNum ? [ownerPIDNum intValue] : 0;

        _ownerName = windowInfo[(NSString *)kCGWindowOwnerName];
        if (!_ownerName) _ownerName = @"";

        NSNumber *isOnScreenNum = windowInfo[(NSString *)kCGWindowIsOnscreen];
        _isOnScreen = isOnScreenNum ? [isOnScreenNum boolValue] : NO;

        // Extract frame information
        NSDictionary *boundsDict = windowInfo[(NSString *)kCGWindowBounds];
        if (boundsDict) {
            CGRect bounds;
            CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDict, &bounds);
            _frame = bounds;
        } else {
            _frame = CGRectZero;
        }

        NSNumber *windowLayer = windowInfo[(NSString *)kCGWindowLayer];
        _level = windowLayer ? [windowLayer intValue] : 0;

        // The sharing type is not directly available from window info
        // We'll need to check it separately
        _sharingType = CGSWindowSharingNone;  // Default assumption

        // Try to find the NSWindow instance for this window ID
        for (NSWindow *window in [NSApp windows]) {
            if ((CGWindowID)[window windowNumber] == _windowID) {
                _nsWindow = window;
                break;
            }
        }

        // Check protection status
        [self checkProtectionStatus];
    }
    return self;
}

#pragma mark - Property Getters

- (CGWindowID)windowID {
    return _windowID;
}

- (NSWindow *)nsWindow {
    return _nsWindow;
}

- (CGRect)frame {
    [self ensureBasicInfoLoaded];
    return _frame;
}

- (NSString *)title {
    [self ensureBasicInfoLoaded];
    return _title;
}

- (pid_t)ownerPID {
    [self ensureBasicInfoLoaded];
    return _ownerPID;
}

- (NSString *)ownerName {
    [self ensureBasicInfoLoaded];
    return _ownerName;
}

- (BOOL)isOnScreen {
    [self ensureBasicInfoLoaded];
    return _isOnScreen;
}

- (NSWindowLevel)level {
    [self ensureExtendedInfoLoaded];
    return _level;
}

- (CGSWindowSharingType)sharingType {
    [self ensureExtendedInfoLoaded];
    return _sharingType;
}

- (BOOL)isProtected {
    [self ensureProtectionStatusChecked];
    return _isProtected;
}

#pragma mark - Private Loading Methods

- (void)ensureBasicInfoLoaded {
    if (!_didLoadBasicInfo) {
        [self loadBasicWindowInfo];
    }
}

- (void)ensureExtendedInfoLoaded {
    if (!_didLoadExtendedInfo) {
        [self loadExtendedWindowInfo];
    }
}

- (void)ensureProtectionStatusChecked {
    if (!_didCheckProtection) {
        [self checkProtectionStatus];
    }
}

- (void)loadBasicWindowInfo {
    if (_didLoadBasicInfo) return;

    // Get window info using Core Graphics
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionIncludingWindow, _windowID);

    if (windowList && CFArrayGetCount(windowList) > 0) {
        NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, 0);

        // Extract window information
        _title = windowInfo[(NSString *)kCGWindowName];
        if (!_title) _title = @"";

        NSNumber *ownerPIDNum = windowInfo[(NSString *)kCGWindowOwnerPID];
        _ownerPID = ownerPIDNum ? [ownerPIDNum intValue] : 0;

        _ownerName = windowInfo[(NSString *)kCGWindowOwnerName];
        if (!_ownerName) _ownerName = @"";

        NSNumber *isOnScreenNum = windowInfo[(NSString *)kCGWindowIsOnscreen];
        _isOnScreen = isOnScreenNum ? [isOnScreenNum boolValue] : NO;

        // Extract frame information
        NSDictionary *boundsDict = windowInfo[(NSString *)kCGWindowBounds];
        if (boundsDict) {
            CGRect bounds;
            CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDict, &bounds);
            _frame = bounds;
        } else {
            _frame = CGRectZero;
        }

        _didLoadBasicInfo = YES;
    } else if (_nsWindow) {
        // Fall back to NSWindow if CGWindowListCopyWindowInfo failed
        _title = [_nsWindow title] ? [_nsWindow title] : @"";
        _frame = [_nsWindow frame];
        _isOnScreen = ![_nsWindow isMiniaturized] && [_nsWindow isVisible];

        // Get the owner process
        NSRunningApplication *app = [NSRunningApplication currentApplication];
        _ownerPID = [app processIdentifier];
        _ownerName = [app localizedName] ? [app localizedName] : @"";

        _didLoadBasicInfo = YES;
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"WindowInfo"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to load basic info for window ID: %d", (int)_windowID];
    }

    if (windowList) {
        CFRelease(windowList);
    }
}

- (void)loadExtendedWindowInfo {
    if (_didLoadExtendedInfo) return;

    // Make sure basic info is loaded first
    [self ensureBasicInfoLoaded];

    // Get window level information
    if (_nsWindow) {
        // For NSWindow, get the window level directly
        _level = [_nsWindow level];

        // Get the sharing type if it's available
        if ([_nsWindow respondsToSelector:@selector(sharingType)]) {
            _sharingType = (CGSWindowSharingType)[_nsWindow sharingType];
        } else {
            _sharingType = CGSWindowSharingNone;  // Default assumption
        }
    } else {
        // For non-AppKit windows, try to use CGS API
        WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

        // Get window level using CGS if available
        if ([cgs canSetWindowLevel]) {
            CGWindowLevel level = 0;
            [cgs performCGSOperation:@"GetWindowLevel"
                        withWindowID:_windowID
                           operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
                // Cast to non-const pointer as required by the CGS function
                return cgs.CGSGetWindowLevel(cid, wid, (CGWindowLevel *)&level);
            }];
            _level = level;
        } else {
            // Fall back to window info from CGWindowList
            CFArrayRef windowList = CGWindowListCopyWindowInfo(
                kCGWindowListOptionIncludingWindow, _windowID);

            if (windowList && CFArrayGetCount(windowList) > 0) {
                NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, 0);
                NSNumber *windowLayer = windowInfo[(NSString *)kCGWindowLayer];
                _level = windowLayer ? [windowLayer intValue] : 0;
            } else {
                _level = 0;  // Default
            }

            if (windowList) {
                CFRelease(windowList);
            }
        }

        // Get window sharing type using CGS if available
        if ([cgs isAvailable] && [cgs canSetWindowSharingState]) {
            CGSWindowSharingType sharingType = CGSWindowSharingNone;
            [cgs performCGSOperation:@"GetWindowSharingState"
                        withWindowID:_windowID
                           operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
                // Cast to non-const pointer as required by the CGS function
                return cgs.CGSGetWindowSharingState(cid, wid, (CGSWindowSharingType *)&sharingType);
            }];
            _sharingType = sharingType;
        } else {
            _sharingType = CGSWindowSharingNone;  // Default assumption
        }
    }

    _didLoadExtendedInfo = YES;
}

- (void)checkProtectionStatus {
    if (_didCheckProtection) return;

    // Check if the window is protected from screen recording
    if (_nsWindow && [_nsWindow respondsToSelector:@selector(sharingType)]) {
        // For NSWindow, check the sharing type directly
        _isProtected = ([_nsWindow sharingType] == NSWindowSharingNone);
    } else {
        // For non-AppKit windows, we need to use CGS
        WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

        if ([cgs isAvailable] && [cgs canSetWindowSharingState]) {
            CGSWindowSharingType sharingType = CGSWindowSharingNone;
            BOOL success = [cgs performCGSOperation:@"GetWindowSharingState"
                                      withWindowID:_windowID
                                         operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
                // Cast to non-const pointer as required by the CGS function
                return cgs.CGSGetWindowSharingState(cid, wid, (CGSWindowSharingType *)&sharingType);
            }];

            if (success) {
                _isProtected = (sharingType == CGSWindowSharingNone);
            } else {
                _isProtected = NO;  // Assume not protected if we couldn't check
            }
        } else {
            _isProtected = NO;  // Assume not protected if CGS is not available
        }
    }

    _didCheckProtection = YES;
}

#pragma mark - Public Methods

- (BOOL)refresh {
    // Reset loaded flags
    _didLoadBasicInfo = NO;
    _didLoadExtendedInfo = NO;
    _didCheckProtection = NO;

    // Check if the window still exists
    if (![self exists]) {
        return NO;
    }

    // Load window information
    [self loadBasicWindowInfo];
    [self loadExtendedWindowInfo];
    [self checkProtectionStatus];

    return YES;
}

- (BOOL)exists {
    // For NSWindow, check if it's still valid
    if (_nsWindow) {
        // A simple check - this could be enhanced with more robust validation
        return [_nsWindow isVisible] || [_nsWindow isMiniaturized];
    }

    // For non-AppKit windows, check if it's in the window list
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionIncludingWindow, _windowID);

    BOOL exists = (windowList && CFArrayGetCount(windowList) > 0);

    if (windowList) {
        CFRelease(windowList);
    }

    return exists;
}

- (BOOL)makeInvisibleToScreenRecording {
    BOOL success = NO;

    // First, try to use CGS API
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if ([cgs isAvailable] && [cgs canSetWindowSharingState]) {
        success = [cgs performCGSOperation:@"SetWindowSharingState"
                              withWindowID:_windowID
                                 operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
            return cgs.CGSSetWindowSharingState(cid, wid, CGSWindowSharingNone);
        }];

        if (success) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Protected window using CGS API: %@", self];
            _sharingType = CGSWindowSharingNone;
            _isProtected = YES;
            _didCheckProtection = YES;
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to protect window using CGS API, trying AppKit fallback: %@", self];
        }
    }

    // If CGS failed or couldn't be applied, fall back to AppKit method if available
    if (!success && _nsWindow && [_nsWindow respondsToSelector:@selector(setSharingType:)]) {
        [_nsWindow setSharingType:NSWindowSharingNone];
        success = YES;

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Protected window using AppKit fallback: %@", self];

        _sharingType = CGSWindowSharingNone;
        _isProtected = YES;
        _didCheckProtection = YES;
    }

    if (!success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to protect window: %@", self];
    }

    return success;
}

- (BOOL)setLevel:(NSWindowLevel)level {
    BOOL success = NO;

    // First, try to use CGS API
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if ([cgs isAvailable] && [cgs canSetWindowLevel]) {
        success = [cgs performCGSOperation:@"SetWindowLevel"
                              withWindowID:_windowID
                                 operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
            return cgs.CGSSetWindowLevel(cid, wid, level);
        }];

        if (success) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowLevel"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Set window level using CGS API: %@", self];
            _level = level;
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowLevel"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to set window level using CGS API, trying AppKit fallback: %@", self];
        }
    }

    // If CGS failed or couldn't be applied, fall back to AppKit method if available
    if (!success && _nsWindow) {
        [_nsWindow setLevel:level];
        success = YES;

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Set window level using AppKit fallback: %@", self];

        _level = level;
    }

    if (!success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to set window level: %@", self];
    }

    return success;
}

- (NSDictionary *)dictionaryRepresentation {
    // Ensure all information is loaded
    [self ensureBasicInfoLoaded];
    [self ensureExtendedInfoLoaded];
    [self ensureProtectionStatusChecked];

    // Create a dictionary representation of the window info
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    dict[@"windowID"] = @(_windowID);
    dict[@"title"] = _title ? _title : @"";
    dict[@"ownerPID"] = @(_ownerPID);
    dict[@"ownerName"] = _ownerName ? _ownerName : @"";
    dict[@"isOnScreen"] = @(_isOnScreen);
    dict[@"level"] = @(_level);
    dict[@"isProtected"] = @(_isProtected);

    // Frame information
    dict[@"frame"] = @{
        @"x": @(_frame.origin.x),
        @"y": @(_frame.origin.y),
        @"width": @(_frame.size.width),
        @"height": @(_frame.size.height)
    };

    // Sharing type
    switch (_sharingType) {
        case CGSWindowSharingNone:
            dict[@"sharingType"] = @"None";
            break;
        case CGSWindowSharingReadOnly:
            dict[@"sharingType"] = @"ReadOnly";
            break;
        case CGSWindowSharingReadWrite:
            dict[@"sharingType"] = @"ReadWrite";
            break;
        default:
            dict[@"sharingType"] = @"Unknown";
            break;
    }

    return dict;
}

#pragma mark - NSObject Overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<WCWindowInfo: windowID=%d, title=%@, protected=%@>",
            (int)_windowID, _title, _isProtected ? @"YES" : @"NO"];
}

@end
