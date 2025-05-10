/**
 * @file profiles.h
 * @brief Profile system for WindowControlInjector
 *
 * This file defines the profile system for WindowControlInjector, which includes
 * predefined profiles for common use cases, profile combination support, and
 * direct property override capabilities.
 */

#ifndef PROFILES_H
#define PROFILES_H

#import <Foundation/Foundation.h>
#import "../src/core/protector.h"
#import "../src/util/logger.h"

/**
 * @brief Profile protocol for WindowControlInjector
 *
 * This protocol defines the interface for WindowControlInjector profiles.
 */
@protocol WCProfile <NSObject>

/**
 * @brief Get the property overrides for this profile
 *
 * This method returns a dictionary of property overrides for this profile.
 * The dictionary is structured as follows:
 * {
 *   "NSClass": {
 *     "property": value,
 *     ...
 *   },
 *   ...
 * }
 *
 * @return Dictionary of property overrides
 */
- (NSDictionary *)propertyOverrides;

/**
 * @brief Get the name of this profile
 *
 * @return Profile name
 */
- (NSString *)name;

@end

/**
 * @brief Invisible profile for WindowControlInjector
 *
 * This profile makes windows invisible to screen recording.
 */
@interface WCInvisibleProfile : NSObject <WCProfile>
@end

/**
 * @brief Stealth profile for WindowControlInjector
 *
 * This profile hides the application from the Dock and status bar.
 */
@interface WCStealthProfile : NSObject <WCProfile>
@end

/**
 * @brief Unfocusable profile for WindowControlInjector
 *
 * This profile prevents windows from receiving focus.
 */
@interface WCUnfocusableProfile : NSObject <WCProfile>
@end

/**
 * @brief ClickThrough profile for WindowControlInjector
 *
 * This profile makes windows click-through (ignores mouse events).
 */
@interface WCClickThroughProfile : NSObject <WCProfile>
@end

/**
 * @brief Profile manager for WindowControlInjector
 *
 * This class manages the application of profiles to target applications.
 */
@interface WCProfileManager : NSObject

/**
 * @brief Get the shared profile manager instance
 *
 * @return Shared profile manager instance
 */
+ (instancetype)sharedManager;

/**
 * @brief Apply a profile to an application
 *
 * This method applies the specified profile to the target application.
 *
 * @param profileName Name of the profile to apply
 * @param applicationPath Path to the application to apply the profile to
 * @param error Error object to return error information
 * @return YES if the profile was applied successfully, NO otherwise
 */
- (BOOL)applyProfile:(NSString *)profileName
    toApplication:(NSString *)applicationPath
           error:(NSError **)error;

/**
 * @brief Apply multiple profiles to an application
 *
 * This method applies the specified profiles to the target application.
 *
 * @param profileNames Array of profile names to apply
 * @param applicationPath Path to the application to apply the profiles to
 * @param error Error object to return error information
 * @return YES if all profiles were applied successfully, NO otherwise
 */
- (BOOL)applyProfiles:(NSArray<NSString *> *)profileNames
       toApplication:(NSString *)applicationPath
              error:(NSError **)error;

/**
 * @brief Apply direct property overrides to an application
 *
 * This method applies the specified property overrides to the target application.
 *
 * @param overrides Dictionary of property overrides
 * @param applicationPath Path to the application to apply the overrides to
 * @param error Error object to return error information
 * @return YES if all overrides were applied successfully, NO otherwise
 */
- (BOOL)applyPropertyOverrides:(NSDictionary *)overrides
                toApplication:(NSString *)applicationPath
                       error:(NSError **)error;

/**
 * @brief Register a custom profile
 *
 * This method registers a custom profile with the profile manager.
 *
 * @param profile Profile to register
 * @return YES if the profile was registered successfully, NO otherwise
 */
- (BOOL)registerProfile:(id<WCProfile>)profile;

/**
 * @brief Get a profile by name
 *
 * This method returns the profile with the specified name.
 *
 * @param profileName Name of the profile to get
 * @return Profile with the specified name, or nil if not found
 */
- (id<WCProfile>)profileWithName:(NSString *)profileName;

@end

// Constants for profile names
extern NSString * const kWCProfileInvisible;
extern NSString * const kWCProfileStealth;
extern NSString * const kWCProfileUnfocusable;
extern NSString * const kWCProfileClickThrough;
extern NSString * const kWCProfileAll;

// Functions for backward compatibility - now use the new profile system
static inline BOOL WCApplyProfile(NSString *profileName, NSString *applicationPath, NSError **error) {
    return [[WCProfileManager sharedManager] applyProfile:profileName
                                          toApplication:applicationPath
                                                 error:error];
}

static inline BOOL WCApplyProfiles(NSArray<NSString *> *profileNames, NSString *applicationPath, NSError **error) {
    return [[WCProfileManager sharedManager] applyProfiles:profileNames
                                           toApplication:applicationPath
                                                  error:error];
}

static inline BOOL WCApplyPropertyOverrides(NSDictionary *overrides, NSString *applicationPath, NSError **error) {
    return [[WCProfileManager sharedManager] applyPropertyOverrides:overrides
                                                    toApplication:applicationPath
                                                           error:error];
}

#endif /* PROFILES_H */
