/**
 * @file profile_manager.h
 * @brief Profile management system for WindowControlInjector
 *
 * This file defines the profile management system used by WindowControlInjector
 * to register and retrieve profiles.
 */

#ifndef PROFILE_MANAGER_H
#define PROFILE_MANAGER_H

#import <Foundation/Foundation.h>
#import "../../include/profiles.h"

/**
 * @brief Profile manager class for WindowControlInjector
 *
 * This class manages profiles for WindowControlInjector.
 */
@interface WCProfileManager : NSObject

/**
 * @brief Get the shared profile manager instance
 *
 * @return The shared profile manager instance
 */
+ (instancetype)sharedManager;

/**
 * @brief Register a profile
 *
 * This method registers a profile with the profile manager.
 *
 * @param profile The profile to register
 * @return YES if the profile was registered successfully, NO otherwise
 */
- (BOOL)registerProfile:(id<WCProfile>)profile;

/**
 * @brief Get a profile by name
 *
 * @param name The name of the profile to get
 * @return The profile, or nil if no profile with the given name exists
 */
- (id<WCProfile>)profileWithName:(NSString *)name;

/**
 * @brief Check if a profile with the given name is registered
 *
 * @param name The name of the profile to check
 * @return YES if a profile with the given name is registered, NO otherwise
 */
- (BOOL)hasProfileWithName:(NSString *)name;

/**
 * @brief Unregister a profile
 *
 * @param name The name of the profile to unregister
 * @return YES if the profile was unregistered successfully, NO otherwise
 */
- (BOOL)unregisterProfileWithName:(NSString *)name;

/**
 * @brief Get all registered profiles
 *
 * @return An array of all registered profiles
 */
- (NSArray<id<WCProfile>> *)allProfiles;

/**
 * @brief Clear all registered profiles
 *
 * @return YES if all profiles were cleared successfully, NO otherwise
 */
- (BOOL)clearAllProfiles;

/**
 * @brief Initialize the profile manager with built-in profiles
 *
 * @return YES if initialization was successful, NO otherwise
 */
- (BOOL)initializeWithBuiltInProfiles;

@end

#endif /* PROFILE_MANAGER_H */
