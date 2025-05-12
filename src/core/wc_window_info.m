/**
 * @file wc_window_info.m
 * @brief Implementation of window information abstraction
 */

#import "wc_window_info.h"
#import "../util/wc_cgs_functions.h"
#import "../util/logger.h"
#import <AppKit/AppKit.h>
#import <dlfcn.h>

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

    // Use NSFloatingWindowLevel for better visibility and Mission Control compatibility
    // instead of whatever level was passed in
    level = NSFloatingWindowLevel;

    // First, try to use CGS API
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if ([cgs isAvailable] && [cgs canSetWindowLevel]) {
        success = [cgs performCGSOperation:@"SetWindowLevel"
                              withWindowID:_windowID
                                 operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
            // Use NSFloatingWindowLevel for optimal visibility and Mission Control compatibility
            return cgs.CGSSetWindowLevel(cid, wid, NSFloatingWindowLevel);
        }];

        if (success) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowLevel"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Set window level using CGS API to NSNormalWindowLevel for Mission Control compatibility: %@", self];
            _level = level;

            // Also set window tags for Mission Control visibility
            [self setWindowTagsForMissionControlVisibility];
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
                                       format:@"Set window level using AppKit fallback to NSNormalWindowLevel: %@", self];

        _level = level;

        // Set window collection behavior for Mission Control visibility
        if ([_nsWindow respondsToSelector:@selector(setCollectionBehavior:)]) {
            NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorDefault;

            // Use the same optimized behavior as in other places
            // Optimized behavior for Mission Control positioning
            behavior |= NSWindowCollectionBehaviorManaged;
            behavior |= NSWindowCollectionBehaviorParticipatesInCycle;
            behavior |= NSWindowCollectionBehaviorMoveToActiveSpace;
            behavior |= NSWindowCollectionBehaviorFullScreenPrimary;

            // Remove behaviors that cause fixed positioning
            behavior &= ~NSWindowCollectionBehaviorStationary;
            behavior &= ~NSWindowCollectionBehaviorCanJoinAllSpaces;
            behavior &= ~NSWindowCollectionBehaviorIgnoresCycle;
            behavior &= ~NSWindowCollectionBehaviorTransient;

            [_nsWindow setCollectionBehavior:behavior];

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"WindowLevel"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Set window collection behavior for Mission Control visibility"];
        }
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

// Method to set window tags for Mission Control visibility
- (BOOL)setWindowTagsForMissionControlVisibility {
    BOOL success = NO;

    // First, get CGSSetWindowTags function
    void *handle = dlopen(NULL, RTLD_LAZY);
    if (!handle) {
        return NO;
    }

    typedef CGError (*CGSSetWindowTagsPtr)(CGSConnectionID, CGWindowID, CGSWindowTag*, int);
    CGSSetWindowTagsPtr setTagsFunc = (CGSSetWindowTagsPtr)dlsym(handle, "CGSSetWindowTags");

    // Get CGSClearWindowTags function
    typedef CGError (*CGSClearWindowTagsPtr)(CGSConnectionID, CGWindowID, CGSWindowTag*, int);
    CGSClearWindowTagsPtr clearTagsFunc = (CGSClearWindowTagsPtr)dlsym(handle, "CGSClearWindowTags");

    if (!setTagsFunc || !clearTagsFunc) {
        dlclose(handle);
        return NO;
    }

    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];
    if ([cgs isAvailable]) {
        CGSConnectionID cid = [cgs CGSDefaultConnection]();
        if (cid != 0) {
            // First, clear any existing tags that might interfere
            CGSWindowTag tagsToClear[5] = { 3, 4, 5, 6, 7 }; // Clear higher level tags
            clearTagsFunc(cid, _windowID, tagsToClear, 5);

            // Set tags for proper Mission Control behavior
            // 1=show in expose, 2=show in window list, 8=allow window to be movable in spaces
            CGSWindowTag tags[3] = { 1, 2, 8 };
            CGError error = setTagsFunc(cid, _windowID, tags, 3);

            // Also modify window level to make it appear at proper level in Mission Control
            // Use kCGDesktopWindowLevel+1 for proper z-ordering
            [cgs performCGSOperation:@"SetWindowLevel"
                         withWindowID:_windowID
                            operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
                return cgs.CGSSetWindowLevel(cid, wid, NSFloatingWindowLevel);
            }];

            if (error == 0) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                             category:@"WindowVisibility"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Applied enhanced CGS window tags for Mission Control visibility to window: %@", self];
                success = YES;
            }

            // If we have a NSWindow reference, set proper collection behavior
            if (_nsWindow && [_nsWindow respondsToSelector:@selector(setCollectionBehavior:)]) {
                NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorDefault;

                // Optimized behavior for Mission Control positioning
                behavior |= NSWindowCollectionBehaviorManaged;
                behavior |= NSWindowCollectionBehaviorParticipatesInCycle;
                behavior |= NSWindowCollectionBehaviorMoveToActiveSpace;

                // More aggressive Mission Control behaviors
                behavior |= NSWindowCollectionBehaviorFullScreenPrimary;

                // Remove behaviors that cause fixed positioning
                behavior &= ~NSWindowCollectionBehaviorStationary;
                behavior &= ~NSWindowCollectionBehaviorCanJoinAllSpaces;

                [_nsWindow setCollectionBehavior:behavior];

                // Set a standard app window level to force proper positioning
                [_nsWindow setLevel:NSNormalWindowLevel];

                success = YES;
            }
        }
    }

    dlclose(handle);
    return success;
}

// Enhanced method to completely disable status bar display - ultra aggressive approach
- (BOOL)disableStatusBar {
    BOOL success = NO;

    // Try AppKit method first
    if (_nsWindow) {
        if ([_nsWindow respondsToSelector:@selector(setStyleMask:)]) {
            // ULTRA aggressive approach - start with borderless window
            NSWindowStyleMask mask = NSWindowStyleMaskBorderless;

            // Add only the styles we want to keep
            mask |= NSWindowStyleMaskResizable;  // Allow resizing
            mask |= NSWindowStyleMaskFullSizeContentView;  // Content extends to full window frame
            mask |= NSWindowStyleMaskNonactivatingPanel;   // Non-activating to prevent focus stealing

            // Explicitly remove all title/status bar related styles
            mask &= ~NSWindowStyleMaskTitled;
            mask &= ~NSWindowStyleMaskUnifiedTitleAndToolbar;
            mask &= ~NSWindowStyleMaskClosable;
            mask &= ~NSWindowStyleMaskMiniaturizable;

            // Apply our minimal style mask
            [_nsWindow setStyleMask:mask];

            // Force title visibility to hidden - try multiple approaches
            if ([_nsWindow respondsToSelector:@selector(setTitleVisibility:)]) {
                [_nsWindow setTitleVisibility:NSWindowTitleHidden];
            }

            // Force titlebar to be fully transparent
            if ([_nsWindow respondsToSelector:@selector(setTitlebarAppearsTransparent:)]) {
                [_nsWindow setTitlebarAppearsTransparent:YES];
            }

            // Set title to empty
            if ([_nsWindow respondsToSelector:@selector(setTitle:)]) {
                [_nsWindow setTitle:@""];
            }

            // Set toolbar to nil
            if ([_nsWindow respondsToSelector:@selector(setToolbar:)]) {
                [_nsWindow setToolbar:nil];
            }

            // Remove any titlebar accessory view controllers
            if ([_nsWindow respondsToSelector:@selector(setTitlebarAccessoryViewControllers:)]) {
                [_nsWindow setTitlebarAccessoryViewControllers:@[]];
            }

            // Set a clear NSAppearance if available to avoid system styling
            if ([_nsWindow respondsToSelector:@selector(setAppearance:)]) {
                if ([NSAppearance respondsToSelector:@selector(appearanceNamed:)]) {
                    NSAppearance *appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
                    if (appearance) {
                        [_nsWindow setAppearance:appearance];
                    }
                }
            }

            // Modern macOS provides better ways to handle title bars
            // Ensure title bar is transparent and hidden
            if ([_nsWindow respondsToSelector:@selector(setMovableByWindowBackground:)]) {
                [_nsWindow setMovableByWindowBackground:YES];
            }

            // Set zero titlebar height if possible using private API (careful approach)
            Class windowClass = [_nsWindow class];
            if ([windowClass instancesRespondToSelector:NSSelectorFromString(@"_setTitlebarHeight:")]) {
                SEL selector = NSSelectorFromString(@"_setTitlebarHeight:");
                NSMethodSignature *signature = [windowClass instanceMethodSignatureForSelector:selector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setSelector:selector];
                [invocation setTarget:_nsWindow];
                CGFloat height = 0.0;
                [invocation setArgument:&height atIndex:2];
                [invocation invoke];

                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                             category:@"WindowStyle"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Applied zero titlebar height using private API"];
            }

            success = YES;

            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"WindowStyle"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Ultra-aggressively disabled status bar for window: %@", self];
        }
    }

    // Use direct CGS API approach as an additional layer if available
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];
    if ([cgs isAvailable]) {
        // Some CGS operations can help with appearance
        CGSConnectionID connection = [cgs CGSDefaultConnection]();
        if (connection != 0) {
            // Try to modify window properties via private APIs - using performSelector to avoid direct references
            SEL shadowSelector = NSSelectorFromString(@"_setDrawsWithoutShadow:");
            if ([_nsWindow respondsToSelector:shadowSelector]) {
                // Use NSInvocation to safely call private selector
                NSMethodSignature *signature = [_nsWindow methodSignatureForSelector:shadowSelector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setSelector:shadowSelector];
                [invocation setTarget:_nsWindow];
                BOOL noShadow = YES;
                [invocation setArgument:&noShadow atIndex:2];
                [invocation invoke];

                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                             category:@"WindowStyle"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Disabled window shadow using private API"];
            }
        }
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
