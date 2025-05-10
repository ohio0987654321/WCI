/**
 * @file interceptor_protocol.h
 * @brief Protocol for standardized interceptor implementation
 *
 * This file defines the protocol that all WindowControlInjector interceptors
 * must follow to ensure consistent behavior and integration with the
 * interceptor registry system.
 */

#ifndef INTERCEPTOR_PROTOCOL_H
#define INTERCEPTOR_PROTOCOL_H

#import <Foundation/Foundation.h>

/**
 * @brief Protocol that defines the standard interface for interceptors
 *
 * All interceptors must implement this protocol to ensure consistent behavior
 * and integration with the interceptor registry system.
 */
@protocol WCInterceptor <NSObject>

@required
/**
 * @brief Get the shared interceptor instance
 *
 * @return The shared interceptor instance
 */
+ (instancetype)sharedInterceptor;

/**
 * @brief Install the interceptor
 *
 * Implement this method to handle the installation of the interceptor.
 * This typically involves swizzling methods or installing observers.
 *
 * @return YES if installation was successful, NO otherwise
 */
+ (BOOL)install;

/**
 * @brief Uninstall the interceptor
 *
 * Implement this method to handle the uninstallation of the interceptor.
 * This typically involves restoring original method implementations
 * and removing observers.
 *
 * @return YES if uninstallation was successful, NO otherwise
 */
+ (BOOL)uninstall;

/**
 * @brief Check if the interceptor is installed
 *
 * @return YES if the interceptor is installed, NO otherwise
 */
+ (BOOL)isInstalled;

/**
 * @brief Get the name of the interceptor
 *
 * This method should return a unique name for the interceptor.
 * This name is used for logging and tracking purposes.
 *
 * @return The name of the interceptor
 */
+ (NSString *)interceptorName;

/**
 * @brief Get the description of what the interceptor does
 *
 * This method should return a description of what the interceptor does.
 * This is used for user feedback and logging.
 *
 * @return The description of the interceptor
 */
+ (NSString *)interceptorDescription;

@optional
/**
 * @brief Register the interceptor with the registry
 *
 * This method is called automatically by the registry system
 * in the +load method of the interceptor class.
 */
+ (void)registerInterceptor;

/**
 * @brief Get the priority of the interceptor
 *
 * Interceptors with higher priority are installed first.
 * Default priority is 0.
 *
 * @return The priority of the interceptor
 */
+ (NSInteger)priority;

/**
 * @brief Get the dependencies of the interceptor
 *
 * Return an array of Class objects representing other interceptors
 * that this interceptor depends on. These interceptors will be
 * installed before this one.
 *
 * @return An array of Class objects for dependent interceptors
 */
+ (NSArray<Class> *)dependencies;

@end

#endif /* INTERCEPTOR_PROTOCOL_H */
