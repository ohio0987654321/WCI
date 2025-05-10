/**
 * @file runtime_utils.h
 * @brief Objective-C runtime utilities for WindowControlInjector
 *
 * This file provides utilities for working with the Objective-C runtime,
 * particularly for method swizzling.
 */

#ifndef RUNTIME_UTILS_H
#define RUNTIME_UTILS_H

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/**
 * @brief Swizzle methods between two selectors in a class
 *
 * This function swizzles the implementations of two selectors in a class.
 *
 * @param cls The class to swizzle methods in
 * @param originalSelector The original selector
 * @param swizzledSelector The swizzled selector
 * @return YES if swizzling was successful, NO otherwise
 */
BOOL WCSwizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector);

/**
 * @brief Swizzle class methods between two selectors in a class
 *
 * This function swizzles the implementations of two class method selectors.
 *
 * @param cls The class to swizzle methods in
 * @param originalSelector The original selector
 * @param swizzledSelector The swizzled selector
 * @return YES if swizzling was successful, NO otherwise
 */
BOOL WCSwizzleClassMethod(Class cls, SEL originalSelector, SEL swizzledSelector);

/**
 * @brief Add a method to a class
 *
 * This function adds a method to a class with the given selector and implementation.
 *
 * @param cls The class to add the method to
 * @param selector The selector for the method
 * @param implementation The implementation function
 * @param typeEncoding The type encoding for the method
 * @return YES if the method was added successfully, NO otherwise
 */
BOOL WCAddMethod(Class cls, SEL selector, IMP implementation, const char *typeEncoding);

/**
 * @brief Replace a method in a class
 *
 * This function replaces the implementation of a method in a class.
 *
 * @param cls The class to replace the method in
 * @param selector The selector for the method
 * @param implementation The new implementation function
 * @return The previous implementation of the method, or NULL if the method did not exist
 */
IMP WCReplaceMethod(Class cls, SEL selector, IMP implementation);

/**
 * @brief Get the implementation of a method in a class
 *
 * @param cls The class to get the method implementation from
 * @param selector The selector for the method
 * @return The implementation of the method, or NULL if the method does not exist
 */
IMP WCGetMethodImplementation(Class cls, SEL selector);

/**
 * @brief Get the type encoding for a method in a class
 *
 * @param cls The class to get the method type encoding from
 * @param selector The selector for the method
 * @return The type encoding for the method, or NULL if the method does not exist
 */
const char *WCGetMethodTypeEncoding(Class cls, SEL selector);

/**
 * @brief Check if a class implements a method
 *
 * @param cls The class to check
 * @param selector The selector for the method
 * @return YES if the class implements the method, NO otherwise
 */
BOOL WCClassImplementsMethod(Class cls, SEL selector);

/**
 * @brief Get a property from a class
 *
 * @param cls The class to get the property from
 * @param propertyName The name of the property
 * @return The property, or NULL if the property does not exist
 */
objc_property_t WCGetProperty(Class cls, const char *propertyName);

/**
 * @brief Helper function to get the getter selector for a property
 *
 * @param property The property to get the getter selector for
 * @return The getter selector for the property
 */
SEL WCGetPropertyGetter(objc_property_t property);

/**
 * @brief Helper function to get the setter selector for a property
 *
 * @param property The property to get the setter selector for
 * @return The setter selector for the property
 */
SEL WCGetPropertySetter(objc_property_t property);

/**
 * @brief Helper function to get the type encoding for a property
 *
 * @param property The property to get the type encoding for
 * @return The type encoding for the property
 */
const char *WCGetPropertyTypeEncoding(objc_property_t property);

/**
 * @brief Helper function to check if a property is atomic
 *
 * @param property The property to check
 * @return YES if the property is atomic, NO otherwise
 */
BOOL WCPropertyIsAtomic(objc_property_t property);

/**
 * @brief Helper function to check if a property is readwrite
 *
 * @param property The property to check
 * @return YES if the property is readwrite, NO otherwise
 */
BOOL WCPropertyIsReadWrite(objc_property_t property);

#endif /* RUNTIME_UTILS_H */
