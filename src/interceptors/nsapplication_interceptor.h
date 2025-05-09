/**
 * @file nsapplication_interceptor.h
 * @brief NSApplication interceptor for WindowControlInjector
 *
 * This file defines the NSApplication interceptor, which intercepts NSApplication method
 * calls and applies property overrides.
 */

#ifndef NSAPPLICATION_INTERCEPTOR_H
#define NSAPPLICATION_INTERCEPTOR_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/**
 * @brief NSApplication interceptor class for WindowControlInjector
 *
 * This class handles the interception of NSApplication method calls.
 */
@interface WCNSApplicationInterceptor : NSObject

/**
 * @brief Install the NSApplication interceptor
 *
 * This method installs the NSApplication interceptor by swizzling methods
 * and applying property overrides.
 *
 * @return YES if the interceptor was installed successfully, NO otherwise
 */
+ (BOOL)install;

/**
 * @brief Uninstall the NSApplication interceptor
 *
 * This method uninstalls the NSApplication interceptor by restoring original
 * method implementations.
 *
 * @return YES if the interceptor was uninstalled successfully, NO otherwise
 */
+ (BOOL)uninstall;

@end

#endif /* NSAPPLICATION_INTERCEPTOR_H */
