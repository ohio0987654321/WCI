/**
 * @file interceptor_registry.h
 * @brief Centralized registry for interceptor management
 *
 * This file defines the registry system for managing all interceptors in a
 * centralized location, allowing for dynamic installation and configuration.
 */

#ifndef INTERCEPTOR_REGISTRY_H
#define INTERCEPTOR_REGISTRY_H

#import <Foundation/Foundation.h>
#import "interceptor_protocol.h"

/**
 * @brief Options for installing interceptors
 */
typedef NS_OPTIONS(NSUInteger, WCInterceptorOptions) {
    WCInterceptorOptionNone          = 0,
    WCInterceptorOptionWindow        = 1 << 0,  // NSWindow interceptor
    WCInterceptorOptionApplication   = 1 << 1,  // NSApplication interceptor
    // Add more interceptor options as needed
    WCInterceptorOptionAll           = UINT_MAX // All interceptors
};

/**
 * @brief Registry for managing all interceptors
 *
 * This class maintains a registry of all interceptors and provides methods
 * for managing their lifecycle.
 */
@interface WCInterceptorRegistry : NSObject

/**
 * @brief Get the shared registry instance
 *
 * @return The shared registry instance
 */
+ (instancetype)sharedRegistry;

/**
 * @brief Register an interceptor class with the registry
 *
 * @param interceptorClass The interceptor class to register
 * @return YES if registration was successful, NO otherwise
 */
- (BOOL)registerInterceptor:(Class<WCInterceptor>)interceptorClass;

/**
 * @brief Unregister an interceptor class from the registry
 *
 * @param interceptorClass The interceptor class to unregister
 * @return YES if unregistration was successful, NO otherwise
 */
- (BOOL)unregisterInterceptor:(Class<WCInterceptor>)interceptorClass;

/**
 * @brief Install all registered interceptors
 *
 * @return YES if all interceptors were installed successfully, NO otherwise
 */
- (BOOL)installAllInterceptors;

/**
 * @brief Install specific interceptors based on options
 *
 * @param options Bitwise OR of WCInterceptorOptions
 * @return YES if selected interceptors were installed successfully, NO otherwise
 */
- (BOOL)installInterceptorsWithOptions:(WCInterceptorOptions)options;

/**
 * @brief Install a specific interceptor
 *
 * @param interceptorClass The interceptor class to install
 * @return YES if the interceptor was installed successfully, NO otherwise
 */
- (BOOL)installInterceptor:(Class<WCInterceptor>)interceptorClass;

/**
 * @brief Uninstall all installed interceptors
 *
 * @return YES if all interceptors were uninstalled successfully, NO otherwise
 */
- (BOOL)uninstallAllInterceptors;

/**
 * @brief Uninstall a specific interceptor
 *
 * @param interceptorClass The interceptor class to uninstall
 * @return YES if the interceptor was uninstalled successfully, NO otherwise
 */
- (BOOL)uninstallInterceptor:(Class<WCInterceptor>)interceptorClass;

/**
 * @brief Check if a specific interceptor is installed
 *
 * @param interceptorClass The interceptor class to check
 * @return YES if the interceptor is installed, NO otherwise
 */
- (BOOL)isInterceptorInstalled:(Class<WCInterceptor>)interceptorClass;

/**
 * @brief Get all registered interceptor classes
 *
 * @return An array of all registered interceptor classes
 */
- (NSArray<Class<WCInterceptor>> *)allRegisteredInterceptors;

/**
 * @brief Get all installed interceptor classes
 *
 * @return An array of all installed interceptor classes
 */
- (NSArray<Class<WCInterceptor>> *)allInstalledInterceptors;

/**
 * @brief Get the interceptor class for a given name
 *
 * @param name The name of the interceptor
 * @return The interceptor class, or nil if not found
 */
- (Class<WCInterceptor>)interceptorClassForName:(NSString *)name;

/**
 * @brief Get the option flag for a given interceptor class
 *
 * @param interceptorClass The interceptor class
 * @return The option flag for the interceptor, or 0 if not mapped
 */
- (WCInterceptorOptions)optionForInterceptor:(Class<WCInterceptor>)interceptorClass;

/**
 * @brief Map an interceptor class to an option flag
 *
 * @param interceptorClass The interceptor class
 * @param option The option flag to map to
 */
- (void)mapInterceptor:(Class<WCInterceptor>)interceptorClass toOption:(WCInterceptorOptions)option;

/**
 * @brief Register all available interceptors
 *
 * This method registers all known interceptors with the registry.
 * It does not install them; to install registered interceptors,
 * call installAllInterceptors.
 *
 * @return YES if all interceptors were registered successfully, NO otherwise
 */
- (BOOL)registerAllInterceptors;

@end

#endif /* INTERCEPTOR_REGISTRY_H */
