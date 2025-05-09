/**
 * @file nswindow_interceptor.h
 * @brief NSWindow interceptor for WindowControlInjector
 *
 * This file defines the NSWindow interceptor, which intercepts NSWindow method
 * calls and applies property overrides.
 */

#ifndef NSWINDOW_INTERCEPTOR_H
#define NSWINDOW_INTERCEPTOR_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/**
 * @brief NSWindow interceptor class for WindowControlInjector
 *
 * This class handles the interception of NSWindow method calls.
 */
@interface WCNSWindowInterceptor : NSObject

/**
 * @brief Install the NSWindow interceptor
 *
 * This method installs the NSWindow interceptor by swizzling methods
 * and applying property overrides.
 *
 * @return YES if the interceptor was installed successfully, NO otherwise
 */
+ (BOOL)install;

/**
 * @brief Uninstall the NSWindow interceptor
 *
 * This method uninstalls the NSWindow interceptor by restoring original
 * method implementations.
 *
 * @return YES if the interceptor was uninstalled successfully, NO otherwise
 */
+ (BOOL)uninstall;

@end

#endif /* NSWINDOW_INTERCEPTOR_H */
