/**
 * @file injector.h
 * @brief Public injection API for WindowControlInjector
 *
 * This file defines the public API for injecting the WindowControlInjector dylib
 * into target applications, with support for various configuration options and
 * features for comprehensive window management across different application types.
 */

#ifndef INJECTOR_H
#define INJECTOR_H

#import <Foundation/Foundation.h>

// Forward declare components
@class WCWindowBridge;
@class WCWindowInfo;
@class WCWindowScanner;
@class WCWindowProtector;
@class WCInjectorConfig;

/**
 * @brief Options for injection features
 */
typedef NS_OPTIONS(NSUInteger, WCInjectionOptions) {
    WCInjectionOptionScreenRecordingProtection = 1 << 0,
    WCInjectionOptionDockIconHiding = 1 << 1,
    WCInjectionOptionAlwaysOnTop = 1 << 2,
    WCInjectionOptionChildProcessProtection = 1 << 3,
    WCInjectionOptionAll = 0xFFFFFFFF
};

/**
 * @brief Configuration for injector with modern options
 */
@interface WCInjectorConfig : NSObject

/**
 * @brief Injection feature options
 */
@property (nonatomic) WCInjectionOptions options;

/**
 * @brief Time interval for window scanning in seconds
 */
@property (nonatomic) NSTimeInterval scanInterval;

/**
 * @brief Whether to protect child processes
 */
@property (nonatomic) BOOL protectChildProcesses;

/**
 * @brief Whether to enable verbose logging
 */
@property (nonatomic) BOOL logVerbose;

/**
 * @brief Get default configuration with all protections enabled
 *
 * @return Default configuration instance
 */
+ (instancetype)defaultConfig;

/**
 * @brief Convert to environment dictionary for injection
 *
 * @return Dictionary of environment variables for injection
 */
- (NSDictionary *)asDictionary;

/**
 * @brief Initialize with dictionary of environment variables
 *
 * @param dict Environment dictionary
 * @return Initialized configuration object
 */
- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

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
 * @brief Inject the WindowControlInjector dylib with specific options
 *
 * This method injects the WindowControlInjector dylib into the specified
 * application with custom configuration options.
 *
 * @param applicationPath Path to the application to inject into
 * @param options Bitwise combination of WCInjectionOptions
 * @param error Error object to return error information
 * @return YES if the injection was successful, NO otherwise
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                      options:(WCInjectionOptions)options
                        error:(NSError **)error;

/**
 * @brief Inject the WindowControlInjector dylib with detailed configuration
 *
 * This method injects the WindowControlInjector dylib into the specified
 * application with a full configuration object.
 *
 * @param applicationPath Path to the application to inject into
 * @param config Configuration object with injection settings
 * @param error Error object to return error information
 * @return YES if the injection was successful, NO otherwise
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                       config:(WCInjectorConfig *)config
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
 * @brief Launch an application with custom configuration
 *
 * This method launches the application with the specified arguments and
 * injects the WindowControlInjector dylib with custom configuration.
 *
 * @param applicationPath Path to the application to launch
 * @param arguments Arguments to pass to the application
 * @param config Configuration object with injection settings
 * @param error Error object to return error information
 * @return NSTask instance for the launched application, or nil if launch failed
 */
+ (NSTask *)launchApplication:(NSString *)applicationPath
                    arguments:(NSArray<NSString *> *)arguments
                       config:(WCInjectorConfig *)config
                        error:(NSError **)error;

/**
 * @brief Launch an application with custom environment variables
 *
 * This method launches the application with the specified arguments and
 * environment variables.
 *
 * @param applicationPath Path to the application to launch
 * @param arguments Arguments to pass to the application
 * @param environment Environment variables for the application
 * @param error Error object to return error information
 * @return NSTask instance for the launched application, or nil if launch failed
 */
+ (NSTask *)launchApplicationWithPath:(NSString *)applicationPath
                            arguments:(NSArray<NSString *> *)arguments
                          environment:(NSDictionary<NSString *, NSString *> *)environment
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
 * @brief Inject the WindowControlInjector dylib with options
 *
 * C function wrapper for [WCInjector injectIntoApplication:options:error:]
 *
 * @param applicationPath Path to the application to inject into
 * @param options Bitwise combination of WCInjectionOptions
 * @param error Error object to return error information
 * @return YES if the injection was successful, NO otherwise
 */
BOOL WCInjectIntoApplicationWithOptions(NSString *applicationPath, WCInjectionOptions options, NSError **error);

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
