/**
 * @file injector.h
 * @brief API for the WindowControlInjector injection mechanism
 *
 * This file defines the API for the injection mechanism used by WindowControlInjector.
 * It provides functions for injecting the WindowControlInjector dylib into target applications.
 */

#ifndef INJECTOR_H
#define INJECTOR_H

#import <Foundation/Foundation.h>

/**
 * @brief WCInjector class for injecting into applications
 *
 * This class provides methods for injecting the WindowControlInjector dylib into target applications.
 */
@interface WCInjector : NSObject

/**
 * @brief Inject into an application with the specified profiles
 *
 * @param applicationPath The path to the application to inject into
 * @param profileNames An array of profile names to apply
 * @param error On return, if an error occurred, a pointer to an NSError object describing the error
 * @return YES if injection was successful, NO otherwise
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                 withProfiles:(NSArray<NSString *> *)profileNames
                        error:(NSError **)error;

/**
 * @brief Inject into an application with custom property overrides
 *
 * @param applicationPath The path to the application to inject into
 * @param overrides A dictionary of property overrides, keyed by class name, with values being dictionaries of property names to values
 * @param error On return, if an error occurred, a pointer to an NSError object describing the error
 * @return YES if injection was successful, NO otherwise
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
        withPropertyOverrides:(NSDictionary *)overrides
                        error:(NSError **)error;

/**
 * @brief Launch an application with the WindowControlInjector dylib injected
 *
 * @param applicationPath The path to the application to launch
 * @param profileNames An array of profile names to apply
 * @param arguments An array of arguments to pass to the application
 * @param error On return, if an error occurred, a pointer to an NSError object describing the error
 * @return The NSTask object representing the launched application, or nil if launch failed
 */
+ (NSTask *)launchApplication:(NSString *)applicationPath
                 withProfiles:(NSArray<NSString *> *)profileNames
                    arguments:(NSArray<NSString *> *)arguments
                        error:(NSError **)error;

/**
 * @brief Launch an application with the WindowControlInjector dylib injected and custom property overrides
 *
 * @param applicationPath The path to the application to launch
 * @param overrides A dictionary of property overrides, keyed by class name, with values being dictionaries of property names to values
 * @param arguments An array of arguments to pass to the application
 * @param error On return, if an error occurred, a pointer to an NSError object describing the error
 * @return The NSTask object representing the launched application, or nil if launch failed
 */
+ (NSTask *)launchApplication:(NSString *)applicationPath
        withPropertyOverrides:(NSDictionary *)overrides
                    arguments:(NSArray<NSString *> *)arguments
                        error:(NSError **)error;

/**
 * @brief Find the path to the WindowControlInjector dylib
 *
 * This method attempts to find the path to the WindowControlInjector dylib, looking in:
 * 1. The same directory as the current executable
 * 2. ~/Library/Application Support/WindowControlInjector/
 * 3. /Library/Application Support/WindowControlInjector/
 *
 * @return The path to the dylib, or nil if not found
 */
+ (NSString *)findDylibPath;

/**
 * @brief Set the path to the WindowControlInjector dylib
 *
 * This method allows setting a custom path to the WindowControlInjector dylib.
 *
 * @param path The path to the dylib
 */
+ (void)setDylibPath:(NSString *)path;

@end

#endif /* INJECTOR_H */
