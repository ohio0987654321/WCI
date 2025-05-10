/**
 * @file injector.h
 * @brief Public injection API for WindowControlInjector
 */

#ifndef INJECTOR_H
#define INJECTOR_H

#import <Foundation/Foundation.h>

// Re-export the core protector API for backward compatibility
#import "../src/core/protector.h"

/**
 * @brief Main injector class for WindowControlInjector
 *
 * This class handles the injection of the WindowControlInjector dylib
 * into target applications.
 */
@interface WCInjector : NSObject

/**
 * @brief Inject the WindowControlInjector dylib into an application
 *
 * This method injects the WindowControlInjector dylib into the specified
 * application using DYLD_INSERT_LIBRARIES.
 *
 * @param applicationPath Path to the application to inject into
 * @param error Error object to return error information
 * @return YES if the injection was successful, NO otherwise
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                        error:(NSError **)error;

/**
 * @brief Launch an application with arguments and injected dylib
 *
 * This method launches the application with the specified arguments and
 * injects the WindowControlInjector dylib.
 *
 * @param applicationPath Path to the application to launch
 * @param arguments Arguments to pass to the application
 * @param error Error object to return error information
 * @return NSTask instance for the launched application, or nil if launch failed
 */
+ (NSTask *)launchApplication:(NSString *)applicationPath
                    arguments:(NSArray<NSString *> *)arguments
                        error:(NSError **)error;

/**
 * @brief Find the path to the WindowControlInjector dylib
 *
 * This method searches for the WindowControlInjector dylib in standard
 * locations and returns the path if found.
 *
 * @return Path to the WindowControlInjector dylib, or nil if not found
 */
+ (NSString *)findDylibPath;

/**
 * @brief Set a custom path for the WindowControlInjector dylib
 *
 * This method sets a custom path for the WindowControlInjector dylib
 * to be used instead of searching for it.
 *
 * @param path Custom path to the WindowControlInjector dylib
 */
+ (void)setDylibPath:(NSString *)path;

@end

// Public C function API for backward compatibility

/**
 * @brief Inject the WindowControlInjector dylib into an application
 *
 * C function wrapper for [WCInjector injectIntoApplication:error:]
 *
 * @param applicationPath Path to the application to inject into
 * @param error Error object to return error information
 * @return YES if the injection was successful, NO otherwise
 */
BOOL WCInjectIntoApplication(NSString *applicationPath, NSError **error);

/**
 * @brief Initialize the WindowControlInjector
 *
 * This function is called when the dylib is loaded to initialize the
 * interceptors.
 *
 * @return YES if initialization was successful, NO otherwise
 */
BOOL WCInitialize(void);

/**
 * @brief Protect an application from screen recording
 *
 * Legacy function for backward compatibility.
 *
 * @param applicationPath Path to the application to protect
 * @param error Error object to return error information
 * @return YES if protection was successful, NO otherwise
 */
BOOL WCProtectApplication(NSString *applicationPath, NSError **error);

/**
 * @brief Get the version string of WindowControlInjector
 *
 * @return Version string
 */
NSString *WCGetVersion(void);

/**
 * @brief Get the build date string of WindowControlInjector
 *
 * @return Build date string
 */
NSString *WCGetBuildDate(void);

#endif /* INJECTOR_H */
