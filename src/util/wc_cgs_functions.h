/**
 * @file wc_cgs_functions.h
 * @brief Core Graphics Services (CGS) function resolution for WindowControlInjector
 *
 * This file defines the interface for resolving and accessing Core Graphics Services (CGS)
 * functions at runtime, which enables universal window control across all application types.
 */

#ifndef WC_CGS_FUNCTIONS_H
#define WC_CGS_FUNCTIONS_H

#import <Foundation/Foundation.h>
#import "wc_cgs_types.h"

/**
 * @brief Manager class for CGS function pointers
 *
 * This class handles the dynamic resolution of CGS functions at runtime
 * and provides a clean interface for accessing them. It uses dlsym to
 * resolve the functions and handles errors gracefully.
 */
@interface WCCGSFunctions : NSObject

/**
 * @brief Get the shared functions manager instance
 *
 * @return Shared singleton instance of WCCGSFunctions
 */
+ (instancetype)sharedFunctions;

/**
 * @brief Core CGS function pointers
 */
@property (nonatomic, readonly) CGSDefaultConnectionPtr CGSDefaultConnection;
@property (nonatomic, readonly) CGSSetWindowSharingStatePtr CGSSetWindowSharingState;
@property (nonatomic, readonly) CGSGetWindowSharingStatePtr CGSGetWindowSharingState;
@property (nonatomic, readonly) CGSSetWindowLevelPtr CGSSetWindowLevel;
@property (nonatomic, readonly) CGSGetWindowLevelPtr CGSGetWindowLevel;

/**
 * @brief Availability checks
 */
- (BOOL)isAvailable;
- (BOOL)canSetWindowSharingState;
- (BOOL)canSetWindowLevel;

/**
 * @brief Function resolution
 *
 * @return YES if all required functions were resolved, NO otherwise
 */
- (BOOL)resolveAllFunctions;

/**
 * @brief Perform a CGS operation with proper error handling
 *
 * @param operationName The name of the operation for logging
 * @param windowID The window ID to operate on
 * @param operation A block that performs the CGS operation
 * @return YES if successful, NO if an error occurred
 */
- (BOOL)performCGSOperation:(NSString *)operationName
                withWindowID:(CGSWindowID)windowID
                   operation:(CGError (^)(CGSConnectionID cid, CGSWindowID wid))operation;

@end

#endif /* WC_CGS_FUNCTIONS_H */
