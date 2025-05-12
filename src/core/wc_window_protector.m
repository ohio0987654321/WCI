/**
 * @file wc_window_protector.m
 * @brief Implementation of window protection utilities
 */

#import "wc_window_protector.h"
#import "wc_window_info.h"
#import "../util/wc_cgs_functions.h"
#import "../util/logger.h"
#import <AppKit/AppKit.h>

// Static variables for debouncing
static NSMutableDictionary<NSNumber *, NSDate *> *lastProtectionTimesByWindowID;
static NSTimeInterval debounceInterval;

@implementation WCWindowProtector

+ (void)initialize {
    if (self == [WCWindowProtector class]) {
        lastProtectionTimesByWindowID = [NSMutableDictionary dictionary];
        debounceInterval = 0.3; // Default to 300ms to prevent flickering
    }
}

/**
 * Set the debounce interval for window protection operations to prevent flickering
 */
+ (void)setDebounceInterval:(NSTimeInterval)interval {
    debounceInterval = interval;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowProtection"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Set protection debounce interval to %.2f seconds", interval];
}

/**
 * Get the current debounce interval
 */
+ (NSTimeInterval)debounceInterval {
    return debounceInterval;
}

/**
 * Clear the debounce history
 */
+ (void)clearDebounceHistory {
    [lastProtectionTimesByWindowID removeAllObjects];
}

#pragma mark - Screen Recording Protection Methods

+ (BOOL)makeWindowInvisibleToScreenRecording:(CGWindowID)windowID {
    // Check if we should debounce this window
    NSNumber *windowIDNumber = @(windowID);
    NSDate *lastProtectionTime = lastProtectionTimesByWindowID[windowIDNumber];

    if (lastProtectionTime) {
        NSTimeInterval timeSinceLastProtection = [[NSDate date] timeIntervalSinceDate:lastProtectionTime];
        if (timeSinceLastProtection < debounceInterval) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Skipping window ID %d protection due to debounce (%.2fs < %.2fs)",
                                                  (int)windowID, timeSinceLastProtection, debounceInterval];
            return YES; // Return success to avoid triggering fallbacks
        }
    }

    // Record this protection attempt
    lastProtectionTimesByWindowID[windowIDNumber] = [NSDate date];

    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if (![cgs canSetWindowSharingState]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"CGSSetWindowSharingState function not available"];
        return NO;
    }

    // Use the CGS API to set window sharing state
    BOOL success = [cgs performCGSOperation:@"SetWindowSharingState"
                              withWindowID:windowID
                                 operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
                                     return cgs.CGSSetWindowSharingState(cid, wid, CGSWindowSharingNone);
                                 }];

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Protected window ID %d from screen recording using CGS API", (int)windowID];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to protect window ID %d from screen recording using CGS API", (int)windowID];
    }

    return success;
}

+ (BOOL)makeNSWindowInvisibleToScreenRecording:(NSWindow *)window {
    if (!window) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Null window pointer provided"];
        return NO;
    }

    // First try to use CGS API if the window has a valid window number
    if ([window respondsToSelector:@selector(windowNumber)] && [window windowNumber] > 0) {
        CGWindowID windowID = (CGWindowID)[window windowNumber];
        BOOL success = [self makeWindowInvisibleToScreenRecording:windowID];

        if (success) {
            return YES;
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowProtection"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to protect window using CGS API, trying AppKit fallback"];
        }
    }

    // Fall back to AppKit method if available
    if ([window respondsToSelector:@selector(setSharingType:)]) {
        [window setSharingType:NSWindowSharingNone];

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Protected window using AppKit fallback: %@", window];
        return YES;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                 category:@"WindowProtection"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Failed to protect window: %@", window];
    return NO;
}

+ (BOOL)makeWindowInfoInvisibleToScreenRecording:(WCWindowInfo *)windowInfo {
    if (!windowInfo) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Null window info pointer provided"];
        return NO;
    }

    // Use the window info's built-in protection method
    BOOL success = [windowInfo makeInvisibleToScreenRecording];

    if (!success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowProtection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to protect window: %@", windowInfo];
    }

    return success;
}

+ (BOOL)protectWindowWithFallback:(id)window {
    // Track which methods were attempted and their results
    NSMutableDictionary *attempts = [NSMutableDictionary dictionary];
    BOOL success = NO;

    // 1. Try CGS API first if we have a window ID
    if ([window respondsToSelector:@selector(windowNumber)]) {
        CGWindowID windowID = [window windowNumber];
        if (windowID > 0) {
            BOOL cgsResult = [self makeWindowInvisibleToScreenRecording:windowID];
            attempts[@"CGS"] = @(cgsResult);
            success = cgsResult;
        }
    }

    // 2. Try NSWindow API if that's available
    if (!success && [window respondsToSelector:@selector(setSharingType:)]) {
        [window setSharingType:NSWindowSharingNone];
        attempts[@"NSWindow"] = @YES;
        success = YES;
    }

    // 3. Try Core Animation API if available - commented out as setSharingProperties: is not a standard method
    /*
    if (!success && [window respondsToSelector:@selector(layer)]) {
        id layer = [window layer];
        // This method is not part of the standard CALayer API, so removed to prevent build errors
        // if ([layer respondsToSelector:@selector(setSharingProperties:)]) {
        //     [layer setSharingProperties:@{@"sharing": @NO}];
        //     attempts[@"CALayer"] = @YES;
        //     success = YES;
        // }
    }
    */

    // Log comprehensive diagnostics
    [[WCLogger sharedLogger] logWithLevel:(success ? WCLogLevelInfo : WCLogLevelWarning)
                                 category:@"WindowProtection"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Window protection %@: %@ - Methods tried: %@",
                                         success ? @"succeeded" : @"failed",
                                         window, attempts];

    return success;
}

#pragma mark - Window Level Methods

+ (BOOL)setWindowLevel:(CGWindowID)windowID toLevel:(NSWindowLevel)level {
    WCCGSFunctions *cgs = [WCCGSFunctions sharedFunctions];

    if (![cgs canSetWindowLevel]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"CGSSetWindowLevel function not available"];
        return NO;
    }

    // Use the CGS API to set window level
    BOOL success = [cgs performCGSOperation:@"SetWindowLevel"
                              withWindowID:windowID
                                 operation:^CGError(CGSConnectionID cid, CGSWindowID wid) {
                                     return cgs.CGSSetWindowLevel(cid, wid, level);
                                 }];

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Set window ID %d to level %ld using CGS API", (int)windowID, (long)level];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to set window ID %d to level %ld using CGS API", (int)windowID, (long)level];
    }

    return success;
}

+ (BOOL)setNSWindowLevel:(NSWindow *)window toLevel:(NSWindowLevel)level {
    if (!window) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Null window pointer provided"];
        return NO;
    }

    // First try to use CGS API if the window has a valid window number
    if ([window respondsToSelector:@selector(windowNumber)] && [window windowNumber] > 0) {
        CGWindowID windowID = (CGWindowID)[window windowNumber];
        BOOL success = [self setWindowLevel:windowID toLevel:level];

        if (success) {
            return YES;
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"WindowLevel"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to set window level using CGS API, trying AppKit fallback"];
        }
    }

    // Use AppKit method
    [window setLevel:level];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"WindowLevel"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Set window level to %ld using AppKit: %@", (long)level, window];
    return YES;
}

+ (BOOL)setWindowInfoLevel:(WCWindowInfo *)windowInfo toLevel:(NSWindowLevel)level {
    if (!windowInfo) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Null window info pointer provided"];
        return NO;
    }

    // Use the window info's built-in level setting method
    BOOL success = [windowInfo setLevel:level];

    if (!success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"WindowLevel"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to set level for window: %@", windowInfo];
    }

    return success;
}

@end
