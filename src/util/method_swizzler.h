/**
 * @file method_swizzler.h
 * @brief Modern method swizzling utilities for WindowControlInjector
 *
 * This file defines a modern, robust method swizzling system with improved
 * safety, error handling, and support for multiple swizzling strategies.
 */

#ifndef METHOD_SWIZZLER_H
#define METHOD_SWIZZLER_H

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/**
 * Types of implementations that can be swizzled
 */
typedef NS_ENUM(NSInteger, WCImplementationType) {
    WCImplementationTypeMethod,       // Regular instance method
    WCImplementationTypeClassMethod,  // Class method
    WCImplementationTypeProperty,     // Property getter/setter
    WCImplementationTypeProtocol      // Protocol method
};

/**
 * Swizzling strategies
 */
typedef NS_ENUM(NSInteger, WCSwizzlingStrategy) {
    WCSwizzlingStrategyExchange,      // Exchange implementations
    WCSwizzlingStrategyReplace,       // Replace the original implementation
    WCSwizzlingStrategyBefore,        // Call custom code before original
    WCSwizzlingStrategyAfter,         // Call custom code after original
    WCSwizzlingStrategyInstead        // Call custom code instead of original, but allow calling original
};

/**
 * @brief Modern method swizzling class for WindowControlInjector
 *
 * This class provides a robust API for method swizzling with improved
 * safety, error handling, and support for multiple swizzling strategies.
 */
@interface WCMethodSwizzler : NSObject

/**
 * @brief Swizzle a method in a class
 *
 * @param cls The class to swizzle
 * @param originalSelector The original selector
 * @param replacementSelector The replacement selector
 * @param implementationType The type of implementation to swizzle
 * @return YES if swizzling was successful, NO otherwise
 */
+ (BOOL)swizzleClass:(Class)cls
    originalSelector:(SEL)originalSelector
 replacementSelector:(SEL)replacementSelector
  implementationType:(WCImplementationType)implementationType;

/**
 * @brief Swizzle a method in a class with a specific strategy
 *
 * @param cls The class to swizzle
 * @param originalSelector The original selector
 * @param replacementSelector The replacement selector
 * @param implementationType The type of implementation to swizzle
 * @param strategy The swizzling strategy to use
 * @return YES if swizzling was successful, NO otherwise
 */
+ (BOOL)swizzleClass:(Class)cls
    originalSelector:(SEL)originalSelector
 replacementSelector:(SEL)replacementSelector
  implementationType:(WCImplementationType)implementationType
            strategy:(WCSwizzlingStrategy)strategy;

/**
 * @brief Add a method to a class
 *
 * @param cls The class to add the method to
 * @param selector The selector for the new method
 * @param implementation The implementation for the new method
 * @param typeEncoding The type encoding for the new method
 * @return YES if the method was added successfully, NO otherwise
 */
+ (BOOL)addMethodToClass:(Class)cls
                selector:(SEL)selector
           implementation:(IMP)implementation
            typeEncoding:(const char *)typeEncoding;

/**
 * @brief Replace a method in a class
 *
 * @param cls The class to replace the method in
 * @param selector The selector for the method
 * @param implementation The new implementation
 * @return The original implementation, or NULL if the method doesn't exist
 */
+ (IMP)replaceMethodInClass:(Class)cls
                   selector:(SEL)selector
              implementation:(IMP)implementation;

/**
 * @brief Get the implementation of a method in a class
 *
 * @param cls The class to get the method from
 * @param selector The selector for the method
 * @param implementationType The type of implementation to get
 * @return The implementation of the method, or NULL if the method doesn't exist
 */
+ (IMP)implementationForClass:(Class)cls
                     selector:(SEL)selector
           implementationType:(WCImplementationType)implementationType;

/**
 * @brief Unswizzle a previously swizzled method
 *
 * @param cls The class to unswizzle
 * @param originalSelector The original selector
 * @param replacementSelector The replacement selector
 * @param implementationType The type of implementation to unswizzle
 * @return YES if unswizzling was successful, NO otherwise
 */
+ (BOOL)unswizzleClass:(Class)cls
      originalSelector:(SEL)originalSelector
   replacementSelector:(SEL)replacementSelector
    implementationType:(WCImplementationType)implementationType;

/**
 * @brief Check if a class implements a method
 *
 * @param cls The class to check
 * @param selector The selector to check for
 * @param implementationType The type of implementation to check for
 * @return YES if the class implements the method, NO otherwise
 */
+ (BOOL)class:(Class)cls
implementsSelector:(SEL)selector
 ofType:(WCImplementationType)implementationType;

/**
 * @brief Get the actual class used for an implementation type
 *
 * For instance methods, this returns the class itself.
 * For class methods, this returns the metaclass.
 *
 * @param cls The input class
 * @param implementationType The implementation type
 * @return The appropriate class object for the implementation type
 */
+ (Class)classForImplementationType:(Class)cls
                 implementationType:(WCImplementationType)implementationType;

/**
 * @brief Store original implementations for later restoration
 *
 * @param cls The class the method belongs to
 * @param selector The method selector
 * @param implementation The implementation to store
 * @param implementationType The type of implementation
 */
+ (void)storeOriginalImplementation:(IMP)implementation
                           forClass:(Class)cls
                           selector:(SEL)selector
                 implementationType:(WCImplementationType)implementationType;

/**
 * @brief Retrieve a previously stored original implementation
 *
 * @param cls The class the method belongs to
 * @param selector The method selector
 * @param implementationType The type of implementation
 * @return The stored implementation, or NULL if not found
 */
+ (IMP)originalImplementationForClass:(Class)cls
                             selector:(SEL)selector
                   implementationType:(WCImplementationType)implementationType;

/**
 * @brief Cleanup all stored implementations
 *
 * This removes all stored original implementations.
 */
+ (void)clearStoredImplementations;

@end

#endif /* METHOD_SWIZZLER_H */
