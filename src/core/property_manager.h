/**
 * @file property_manager.h
 * @brief Property management system for WindowControlInjector
 *
 * This file defines the property management system used by WindowControlInjector
 * to override property values for classes.
 */

#ifndef PROPERTY_MANAGER_H
#define PROPERTY_MANAGER_H

#import <Foundation/Foundation.h>

/**
 * @brief Property manager class for WindowControlInjector
 *
 * This class manages property overrides for classes.
 */
@interface WCPropertyManager : NSObject

/**
 * @brief Get the shared property manager instance
 *
 * @return The shared property manager instance
 */
+ (instancetype)sharedManager;

/**
 * @brief Apply a profile to the current application
 *
 * This method applies the property overrides defined in a profile to the current application.
 * If the profile has dependencies, they will be applied first.
 *
 * @param profileName The name of the profile to apply
 * @return YES if the profile was applied successfully, NO otherwise
 */
- (BOOL)applyProfile:(NSString *)profileName;

/**
 * @brief Set an override value for a property on a class
 *
 * This method sets an override value for a property on a class.
 *
 * @param value The value to override the property with
 * @param propertyName The name of the property to override
 * @param className The name of the class the property belongs to
 * @return YES if the override was set successfully, NO otherwise
 */
- (BOOL)setOverrideValue:(id)value forProperty:(NSString *)propertyName onClass:(NSString *)className;

/**
 * @brief Get the current override value for a property on a class
 *
 * @param propertyName The name of the property
 * @param className The name of the class the property belongs to
 * @return The override value, or nil if no override is set
 */
- (id)overrideValueForProperty:(NSString *)propertyName onClass:(NSString *)className;

/**
 * @brief Check if a property has an override value set
 *
 * @param propertyName The name of the property
 * @param className The name of the class the property belongs to
 * @return YES if the property has an override value set, NO otherwise
 */
- (BOOL)hasOverrideForProperty:(NSString *)propertyName onClass:(NSString *)className;

/**
 * @brief Remove an override value for a property on a class
 *
 * @param propertyName The name of the property
 * @param className The name of the class the property belongs to
 * @return YES if the override was removed successfully, NO otherwise
 */
- (BOOL)removeOverrideForProperty:(NSString *)propertyName onClass:(NSString *)className;

/**
 * @brief Apply multiple property overrides at once
 *
 * This method applies multiple property overrides at once. The overrides are specified
 * as a dictionary of class names to dictionaries of property names to values.
 *
 * @param overrides A dictionary of property overrides
 * @return YES if all overrides were applied successfully, NO otherwise
 */
- (BOOL)applyPropertyOverrides:(NSDictionary *)overrides;

/**
 * @brief Clear all property overrides
 *
 * @return YES if all overrides were cleared successfully, NO otherwise
 */
- (BOOL)clearAllOverrides;

/**
 * @brief Get a dictionary of all current property overrides
 *
 * @return A dictionary of all current property overrides
 */
- (NSDictionary *)allOverrides;

/**
 * @brief Get a dictionary of property overrides for a specific class
 *
 * @param className The name of the class
 * @return A dictionary of property overrides for the specified class
 */
- (NSDictionary *)overridesForClass:(NSString *)className;

@end

// C function wrappers for the public API
BOOL WCSetOverrideValue(id value, NSString *propertyName, NSString *className);
id WCGetOverrideValue(NSString *propertyName, NSString *className);

#endif /* PROPERTY_MANAGER_H */
