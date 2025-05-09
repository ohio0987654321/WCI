/**
 * @file profiles.h
 * @brief Defines the WCProfile protocol and profile names
 *
 * This file defines the WCProfile protocol that all profiles must implement,
 * as well as constants for the built-in profile names.
 */

#ifndef PROFILES_H
#define PROFILES_H

#import <Foundation/Foundation.h>

/**
 * @brief Protocol for WindowControlInjector profiles
 *
 * All profiles must implement this protocol, which defines the methods
 * a profile must implement to provide property overrides.
 */
@protocol WCProfile <NSObject>

/**
 * @brief Get the name of the profile
 *
 * @return The name of the profile as an NSString
 */
- (NSString *)name;

/**
 * @brief Get the property overrides for this profile
 *
 * Returns a dictionary of property overrides, keyed by class name, with values
 * being dictionaries of property names to values.
 *
 * @return A dictionary of property overrides
 */
- (NSDictionary *)propertyOverrides;

/**
 * @brief Get the dependencies of this profile
 *
 * Returns an array of profile names that this profile depends on. The dependencies
 * will be applied before this profile is applied.
 *
 * @return An array of profile names, or nil if there are no dependencies
 */
- (NSArray<NSString *> *)dependencies;

/**
 * @brief Get the description of this profile
 *
 * Returns a human-readable description of what this profile does.
 *
 * @return A human-readable description
 */
- (NSString *)profileDescription;

@end

// Built-in profile names
extern NSString * const WCProfileNameInvisible;
extern NSString * const WCProfileNameStealth;
extern NSString * const WCProfileNameUnfocusable;
extern NSString * const WCProfileNameClickThrough;

/**
 * @brief Register a custom profile
 *
 * This function registers a custom profile with the WindowControlInjector.
 * The profile must implement the WCProfile protocol.
 *
 * @param profile The profile to register
 * @return YES if the profile was registered successfully, NO otherwise
 */
BOOL WCRegisterProfile(id<WCProfile> profile);

/**
 * @brief Get a registered profile by name
 *
 * @param name The name of the profile to get
 * @return The profile, or nil if no profile with the given name exists
 */
id<WCProfile> WCGetProfile(NSString *name);

/**
 * @brief Get all registered profiles
 *
 * @return An array of all registered profiles
 */
NSArray<id<WCProfile>> *WCGetAllProfiles(void);

/**
 * @brief Check if a profile is registered
 *
 * @param name The name of the profile to check
 * @return YES if a profile with the given name is registered, NO otherwise
 */
BOOL WCIsProfileRegistered(NSString *name);

#endif /* PROFILES_H */
