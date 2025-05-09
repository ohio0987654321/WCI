/**
 * @file window_control.h
 * @brief Main public API for WindowControlInjector
 *
 * This file defines the main public API for WindowControlInjector, a macOS utility
 * that uses dylib injection to modify the behavior and appearance of target applications.
 */

#ifndef WINDOW_CONTROL_H
#define WINDOW_CONTROL_H

#import <Foundation/Foundation.h>

// Version information
#define WC_VERSION_MAJOR 1
#define WC_VERSION_MINOR 0
#define WC_VERSION_PATCH 0
#define WC_VERSION_STRING "1.0.0"

// Error domain
extern NSErrorDomain const WCErrorDomain;

// Error codes
typedef NS_ENUM(NSInteger, WCErrorCode) {
    WCErrorApplicationNotFound = 1000,
    WCErrorInjectionFailed,
    WCErrorProfileNotFound,
    WCErrorInvalidPropertyValue,
    WCErrorUnknownProperty,
    WCErrorInvalidArguments
};

// Forward declarations
@protocol WCProfile;
@class WCInjector;
@class WCPropertyManager;

/**
 * @brief Initialize the WindowControlInjector library.
 *
 * This function must be called before using any other WindowControlInjector functions.
 * It is automatically called when the library is loaded via DYLD_INSERT_LIBRARIES.
 *
 * @return YES if initialization was successful, NO otherwise.
 */
BOOL WCInitialize(void);

/**
 * @brief Get the version of the WindowControlInjector library.
 *
 * @return An NSString containing the version number.
 */
NSString *WCGetVersion(void);

/**
 * @brief Get the build date of the WindowControlInjector library.
 *
 * @return An NSString containing the build date.
 */
NSString *WCGetBuildDate(void);

/**
 * @brief Inject into an application with the specified profiles.
 *
 * @param applicationPath The path to the application to inject into.
 * @param profileNames An array of profile names to apply.
 * @param error On return, if an error occurred, a pointer to an NSError object describing the error.
 * @return YES if injection was successful, NO otherwise.
 */
BOOL WCInjectIntoApplication(NSString *applicationPath, NSArray<NSString *> *profileNames, NSError **error);

/**
 * @brief Inject into an application with custom property overrides.
 *
 * @param applicationPath The path to the application to inject into.
 * @param overrides A dictionary of property overrides, keyed by class name, with values being dictionaries of property names to values.
 * @param error On return, if an error occurred, a pointer to an NSError object describing the error.
 * @return YES if injection was successful, NO otherwise.
 */
BOOL WCInjectIntoApplicationWithOverrides(NSString *applicationPath, NSDictionary *overrides, NSError **error);

/**
 * @brief Apply a profile to the current application.
 *
 * This function is used internally by the injected library to apply a profile to the
 * current application. It should not be called directly by client code.
 *
 * @param profileName The name of the profile to apply.
 * @return YES if the profile was applied successfully, NO otherwise.
 */
BOOL WCApplyProfile(NSString *profileName);

/**
 * @brief Override a property value for a class.
 *
 * This function is used internally by the injected library to override property values.
 * It should not be called directly by client code.
 *
 * @param value The value to override the property with.
 * @param propertyName The name of the property to override.
 * @param className The name of the class the property belongs to.
 * @return YES if the override was set successfully, NO otherwise.
 */
BOOL WCSetOverrideValue(id value, NSString *propertyName, NSString *className);

/**
 * @brief Get the current override value for a property on a class.
 *
 * @param propertyName The name of the property.
 * @param className The name of the class the property belongs to.
 * @return The override value, or nil if no override is set.
 */
id WCGetOverrideValue(NSString *propertyName, NSString *className);

/**
 * @brief Enable logging for the WindowControlInjector library.
 *
 * @param enabled YES to enable logging, NO to disable.
 */
void WCSetLoggingEnabled(BOOL enabled);

/**
 * @brief Set the log level for the WindowControlInjector library.
 *
 * @param level The log level to set (0 = none, 1 = error, 2 = warning, 3 = info, 4 = debug).
 */
void WCSetLogLevel(NSInteger level);

#endif /* WINDOW_CONTROL_H */
