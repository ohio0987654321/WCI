/**
 * @file protector.h
 * @brief Core protection functionality for WindowControlInjector
 */

#ifndef PROTECTOR_H
#define PROTECTOR_H

#import <Foundation/Foundation.h>

// Error domain for protection operations
extern NSString *const WCProtectorErrorDomain;

/**
 * @brief Core protector class that implements all protection features
 */
@interface WCProtector : NSObject

/**
 * @brief Apply all protection features to the specified application
 *
 * This method applies screen recording protection, dock hiding, and
 * menu bar hiding features to the specified application.
 *
 * @param applicationPath The path to the application to protect
 * @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information.
 * @return YES if successful, NO otherwise
 */
+ (BOOL)protectApplication:(NSString *)applicationPath error:(NSError **)error;

/**
 * @brief Apply specific property overrides to the specified application
 *
 * This method applies the specified property overrides to the application.
 *
 * @param applicationPath The path to the application to protect
 * @param properties A dictionary of properties to override
 * @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object containing the error information.
 * @return YES if successful, NO otherwise
 */
+ (BOOL)protectApplicationWithProperties:(NSString *)applicationPath
                         withProperties:(NSDictionary *)properties
                                  error:(NSError **)error;

/**
 * @brief Initialize the WindowControlInjector
 *
 * @return YES if successful, NO otherwise
 */
+ (BOOL)initialize;

/**
 * @brief Set the logging level
 *
 * @param logLevel The log level to set
 */
+ (void)setLogLevel:(NSInteger)logLevel;

@end

// C function wrappers for the public API
BOOL WCProtectApplication(NSString *applicationPath, NSError **error);
BOOL WCProtectApplicationWithProperties(NSString *applicationPath, NSDictionary *properties, NSError **error);
BOOL WCInitialize(void);

#endif /* PROTECTOR_H */
