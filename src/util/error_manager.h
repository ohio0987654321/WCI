/**
 * @file error_manager.h
 * @brief Enhanced error handling framework for WindowControlInjector
 *
 * This file defines a structured error handling system with categorized errors,
 * detailed information, and suggestions for resolution.
 */

#ifndef ERROR_MANAGER_H
#define ERROR_MANAGER_H

#import <Foundation/Foundation.h>

// Primary error domain for the application
extern NSString * const WCErrorDomain;

/**
 * Error categories for organizing errors by subsystem
 */
typedef NS_ENUM(NSInteger, WCErrorCategory) {
    WCErrorCategoryLaunch = 1000,           // Application launch errors
    WCErrorCategoryInjection = 2000,        // Dylib injection errors
    WCErrorCategoryConfiguration = 3000,     // Configuration errors
    WCErrorCategoryInterception = 4000,      // Method interception errors
    WCErrorCategoryRuntime = 5000,          // Runtime and execution errors
    WCErrorCategoryPath = 6000,             // Path resolution errors
    WCErrorCategorySystem = 7000,           // System-level errors
    WCErrorCategoryGeneral = 9000           // General/uncategorized errors
};

// Launch error codes (1000-1999)
typedef NS_ENUM(NSInteger, WCLaunchErrorCode) {
    WCLaunchErrorApplicationPathNil = 1001,
    WCLaunchErrorApplicationNotFound = 1002,
    WCLaunchErrorApplicationLaunchFailed = 1003,
    WCLaunchErrorLaunchTimeout = 1004,
    WCLaunchErrorInvalidApplicationBundle = 1005,
    WCLaunchErrorExecutableNotFound = 1006
};

// Injection error codes (2000-2999)
typedef NS_ENUM(NSInteger, WCInjectionErrorCode) {
    WCInjectionErrorDylibNotFound = 2001,
    WCInjectionErrorDylibLoadFailed = 2002,
    WCInjectionErrorDylibIsInvalid = 2003,
    WCInjectionErrorInjectionFailed = 2004,
    WCInjectionErrorPermissionDenied = 2005
};

// Configuration error codes (3000-3999)
typedef NS_ENUM(NSInteger, WCConfigurationErrorCode) {
    WCConfigurationErrorInvalidFormat = 3001,
    WCConfigurationErrorMissingRequiredValue = 3002,
    WCConfigurationErrorInvalidValue = 3003,
    WCConfigurationErrorFileSaveFailed = 3004,
    WCConfigurationErrorFileLoadFailed = 3005,
    WCConfigurationErrorParsingFailed = 3006
};

// Interception error codes (4000-4999)
typedef NS_ENUM(NSInteger, WCInterceptionErrorCode) {
    WCInterceptionErrorClassNotFound = 4001,
    WCInterceptionErrorMethodNotFound = 4002,
    WCInterceptionErrorSwizzlingFailed = 4003,
    WCInterceptionErrorIncompatibleTypes = 4004,
    WCInterceptionErrorSwizzlingNotSupported = 4005,
    WCInterceptionErrorInterceptorAlreadyInstalled = 4006,
    WCInterceptionErrorInterceptorInstallFailed = 4007,
    WCInterceptionErrorInterceptorNotInstalled = 4008
};

// Runtime error codes (5000-5999)
typedef NS_ENUM(NSInteger, WCRuntimeErrorCode) {
    WCRuntimeErrorUnknown = 5001,
    WCRuntimeErrorMemoryAllocationFailed = 5002,
    WCRuntimeErrorInvalidState = 5003,
    WCRuntimeErrorOperationTimeout = 5004,
    WCRuntimeErrorInvalidArgument = 5005,
    WCRuntimeErrorTypeMismatch = 5006
};

// Path resolution error codes (6000-6999)
typedef NS_ENUM(NSInteger, WCPathErrorCode) {
    WCPathErrorFileNotFound = 6001,
    WCPathErrorDirectoryNotFound = 6002,
    WCPathErrorInvalidPath = 6003,
    WCPathErrorPermissionDenied = 6004,
    WCPathErrorSymlinkResolutionFailed = 6005,
    WCPathErrorExecutableNotFound = 6006
};

// System error codes (7000-7999)
typedef NS_ENUM(NSInteger, WCSystemErrorCode) {
    WCSystemErrorUnknown = 7001,
    WCSystemErrorSecurityRestriction = 7002,
    WCSystemErrorInsufficientPermissions = 7003,
    WCSystemErrorSystemServiceUnavailable = 7004,
    WCSystemErrorIncompatibleOS = 7005,
    WCSystemErrorProcessLimitReached = 7006
};

/**
 * @brief Enhanced error class for WindowControlInjector
 *
 * This class extends NSError with additional context and recovery suggestions.
 */
@interface WCError : NSError

/**
 * @brief Create an error with category, code, and message
 *
 * @param category The error category (subsystem)
 * @param code The error code within the category
 * @param message The human-readable error message
 * @return A new error instance
 */
+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message;

/**
 * @brief Create an error with category, code, message, and details
 *
 * @param category The error category (subsystem)
 * @param code The error code within the category
 * @param message The human-readable error message
 * @param details Additional details as a dictionary
 * @return A new error instance
 */
+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message
                         details:(NSDictionary *)details;

/**
 * @brief Create an error with category, code, message, details, and suggestion
 *
 * @param category The error category (subsystem)
 * @param code The error code within the category
 * @param message The human-readable error message
 * @param details Additional details as a dictionary
 * @param suggestion A suggested action to resolve the error
 * @return A new error instance
 */
+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message
                         details:(NSDictionary *)details
                      suggestion:(NSString *)suggestion;

/**
 * @brief Create an error with category, code, message, details, suggestion, and underlying error
 *
 * @param category The error category (subsystem)
 * @param code The error code within the category
 * @param message The human-readable error message
 * @param details Additional details as a dictionary
 * @param suggestion A suggested action to resolve the error
 * @param underlyingError The underlying error that caused this error
 * @return A new error instance
 */
+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message
                         details:(NSDictionary *)details
                      suggestion:(NSString *)suggestion
                 underlyingError:(NSError *)underlyingError;

/**
 * @brief Get the error category
 *
 * @return The error category
 */
- (WCErrorCategory)errorCategory;

/**
 * @brief Get the error details
 *
 * @return The error details dictionary
 */
- (NSDictionary *)errorDetails;

/**
 * @brief Get the error suggestion
 *
 * @return The error suggestion
 */
- (NSString *)errorSuggestion;

/**
 * @brief Get a detailed diagnostic string for the error
 *
 * @return A detailed diagnostic string
 */
- (NSString *)diagnosticDescription;

/**
 * @brief Get a user-friendly description with a suggestion
 *
 * @return A user-friendly description with a suggestion
 */
- (NSString *)userFriendlyDescription;

/**
 * @brief Check if this error belongs to a specific category
 *
 * @param category The category to check
 * @return YES if the error belongs to the category, NO otherwise
 */
- (BOOL)isInCategory:(WCErrorCategory)category;

@end

#endif /* ERROR_MANAGER_H */
