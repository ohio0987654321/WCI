/**
 * @file nsapplication_interceptor.h
 * @brief NSApplication interceptor for WindowControlInjector
 *
 * This file defines the NSApplication interceptor that manages
 * application-level behavior and implements the WCInterceptor protocol.
 */

#ifndef NSAPPLICATION_INTERCEPTOR_H
#define NSAPPLICATION_INTERCEPTOR_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "interceptor_protocol.h"

/**
 * @brief NSApplication interceptor class for WindowControlInjector
 *
 * This class handles the interception of NSApplication method calls to implement
 * application-level controls and behaviors. It follows a singleton pattern and
 * uses the improved method swizzling system. Conforms to the WCInterceptor protocol.
 */
@interface WCNSApplicationInterceptor : NSObject <WCInterceptor>

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
// + (NSArray<Class> *)dependencies;

/**
 * @brief Apply protections to the application
 *
 * This method applies protection measures to the NSApplication instance.
 * It's called during installation and can be called manually to refresh
 * protection settings.
 */
- (void)applyProtectionsToApplication;

@end

#endif /* NSAPPLICATION_INTERCEPTOR_H */
