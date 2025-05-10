/**
 * @file nswindow_interceptor.h
 * @brief NSWindow interceptor for WindowControlInjector
 *
 * This file defines the NSWindow interceptor that manages window-level
 * behavior and implements the WCInterceptor protocol.
 */

#ifndef NSWINDOW_INTERCEPTOR_H
#define NSWINDOW_INTERCEPTOR_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "interceptor_protocol.h"

/**
 * @brief NSWindow interceptor class for WindowControlInjector
 *
 * This class handles the interception of NSWindow method calls to implement
 * window-level controls and behaviors. It follows a singleton pattern and
 * uses the improved method swizzling system. Conforms to the WCInterceptor protocol.
 */
@interface WCNSWindowInterceptor : NSObject <WCInterceptor>

// WCInterceptor protocol methods are declared in the protocol itself
// We implement these methods:
// + (instancetype)sharedInterceptor;
// + (BOOL)install;
// + (BOOL)uninstall;
// + (BOOL)isInstalled;
// + (NSString *)interceptorName;
// + (NSString *)interceptorDescription;

// Optional protocol methods we implement:
// + (NSInteger)priority;

/**
 * @brief Apply protections to a window
 *
 * This method applies protection measures to the specified NSWindow instance.
 * It's called during installation and by notification handlers to refresh
 * protection settings on specific windows.
 *
 * @param window The NSWindow instance to apply protections to
 */
- (void)applyProtectionsToWindow:(NSWindow *)window;

@end

#endif /* NSWINDOW_INTERCEPTOR_H */
