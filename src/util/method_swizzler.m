/**
 * @file method_swizzler.m
 * @brief Implementation of modern method swizzling utilities for WindowControlInjector
 */

#import "method_swizzler.h"
#import "logger.h"
#import "error_manager.h"

// Dictionary to store original implementations for unswizzling
static NSMutableDictionary *originalImplementations = nil;

// Key generation for implementation storage
static NSString *WCImplementationKeyForMethod(Class cls, SEL selector, WCImplementationType type) {
    return [NSString stringWithFormat:@"%@_%@_%ld",
            NSStringFromClass(cls),
            NSStringFromSelector(selector),
            (long)type];
}

@implementation WCMethodSwizzler

#pragma mark - Initialization

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        originalImplementations = [NSMutableDictionary dictionary];
    });
}

#pragma mark - Public Methods

+ (BOOL)swizzleClass:(Class)cls
    originalSelector:(SEL)originalSelector
 replacementSelector:(SEL)replacementSelector
  implementationType:(WCImplementationType)implementationType {

    return [self swizzleClass:cls
              originalSelector:originalSelector
           replacementSelector:replacementSelector
            implementationType:implementationType
                      strategy:WCSwizzlingStrategyExchange];
}

+ (BOOL)swizzleClass:(Class)cls
    originalSelector:(SEL)originalSelector
 replacementSelector:(SEL)replacementSelector
  implementationType:(WCImplementationType)implementationType
            strategy:(WCSwizzlingStrategy)strategy {

    // Input validation
    if (!cls || !originalSelector || !replacementSelector) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Invalid arguments for swizzling"];
        return NO;
    }

    // Get the appropriate class based on implementation type
    Class targetClass = [self classForImplementationType:cls implementationType:implementationType];
    if (!targetClass) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to get class for implementation type %ld", (long)implementationType];
        return NO;
    }

    // Get methods
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method replacementMethod = class_getInstanceMethod(targetClass, replacementSelector);

    // Check if methods exist
    if (!originalMethod) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Original method %@ not found in class %@",
                                              NSStringFromSelector(originalSelector), NSStringFromClass(targetClass)];
        return NO;
    }

    if (!replacementMethod) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Replacement method %@ not found in class %@",
                                              NSStringFromSelector(replacementSelector), NSStringFromClass(targetClass)];
        return NO;
    }

    // Get implementations and type encodings
    IMP originalImplementation = method_getImplementation(originalMethod);
    IMP replacementImplementation = method_getImplementation(replacementMethod);
    const char *originalTypeEncoding = method_getTypeEncoding(originalMethod);
    const char *replacementTypeEncoding = method_getTypeEncoding(replacementMethod);

    // Store original implementation for later restoration
    [self storeOriginalImplementation:originalImplementation
                             forClass:targetClass
                             selector:originalSelector
                   implementationType:implementationType];

    // Perform swizzling based on strategy
    BOOL success = NO;

    switch (strategy) {
        case WCSwizzlingStrategyExchange:
            success = [self exchangeImplementations:originalMethod replacementMethod:replacementMethod];
            break;

        case WCSwizzlingStrategyReplace:
            success = [self replaceImplementation:originalMethod withImplementation:replacementImplementation];
            break;

        case WCSwizzlingStrategyBefore:
        case WCSwizzlingStrategyAfter:
        case WCSwizzlingStrategyInstead:
            // These strategies require more complex handling and would need to be expanded
            // with a more sophisticated approach such as using block-based implementations
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                        category:WCLogCategoryInterception
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Swizzling strategy %ld not implemented yet", (long)strategy];
            success = NO;
            break;
    }

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully swizzled %@ with %@ in class %@",
                                              NSStringFromSelector(originalSelector),
                                              NSStringFromSelector(replacementSelector),
                                              NSStringFromClass(targetClass)];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to swizzle %@ with %@ in class %@",
                                              NSStringFromSelector(originalSelector),
                                              NSStringFromSelector(replacementSelector),
                                              NSStringFromClass(targetClass)];
    }

    return success;
}

+ (BOOL)addMethodToClass:(Class)cls
                selector:(SEL)selector
           implementation:(IMP)implementation
            typeEncoding:(const char *)typeEncoding {

    // Input validation
    if (!cls || !selector || !implementation || !typeEncoding) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Invalid arguments for adding method"];
        return NO;
    }

    // Check if method already exists
    if (class_getInstanceMethod(cls, selector)) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Method %@ already exists in class %@",
                                              NSStringFromSelector(selector), NSStringFromClass(cls)];
        return NO;
    }

    // Add method
    BOOL success = class_addMethod(cls, selector, implementation, typeEncoding);

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully added method %@ to class %@",
                                              NSStringFromSelector(selector), NSStringFromClass(cls)];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to add method %@ to class %@",
                                              NSStringFromSelector(selector), NSStringFromClass(cls)];
    }

    return success;
}

+ (IMP)replaceMethodInClass:(Class)cls
                   selector:(SEL)selector
              implementation:(IMP)implementation {

    // Input validation
    if (!cls || !selector || !implementation) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Invalid arguments for replacing method"];
        return NULL;
    }

    // Get the method
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Method %@ not found in class %@",
                                              NSStringFromSelector(selector), NSStringFromClass(cls)];
        return NULL;
    }

    // Get the type encoding
    const char *typeEncoding = method_getTypeEncoding(method);

    // Store original implementation
    IMP originalImplementation = method_getImplementation(method);

    // Replace the method
    class_replaceMethod(cls, selector, implementation, typeEncoding);

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryInterception
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Successfully replaced method %@ in class %@",
                                          NSStringFromSelector(selector), NSStringFromClass(cls)];

    return originalImplementation;
}

+ (IMP)implementationForClass:(Class)cls
                     selector:(SEL)selector
           implementationType:(WCImplementationType)implementationType {

    // Input validation
    if (!cls || !selector) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Invalid arguments for getting implementation"];
        return NULL;
    }

    // Get the appropriate class based on implementation type
    Class targetClass = [self classForImplementationType:cls implementationType:implementationType];
    if (!targetClass) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to get class for implementation type %ld", (long)implementationType];
        return NULL;
    }

    // Get the method
    Method method = class_getInstanceMethod(targetClass, selector);
    if (!method) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Method %@ not found in class %@",
                                              NSStringFromSelector(selector), NSStringFromClass(targetClass)];
        return NULL;
    }

    return method_getImplementation(method);
}

+ (BOOL)unswizzleClass:(Class)cls
      originalSelector:(SEL)originalSelector
   replacementSelector:(SEL)replacementSelector
    implementationType:(WCImplementationType)implementationType {

    // Input validation
    if (!cls || !originalSelector || !replacementSelector) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Invalid arguments for unswizzling"];
        return NO;
    }

    // Get the appropriate class based on implementation type
    Class targetClass = [self classForImplementationType:cls implementationType:implementationType];
    if (!targetClass) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to get class for implementation type %ld", (long)implementationType];
        return NO;
    }

    // Get methods
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method replacementMethod = class_getInstanceMethod(targetClass, replacementSelector);

    // Check if methods exist
    if (!originalMethod || !replacementMethod) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Methods not found in class %@", NSStringFromClass(targetClass)];
        return NO;
    }

    // Get the stored original implementation
    IMP originalImplementation = [self originalImplementationForClass:targetClass
                                                             selector:originalSelector
                                                   implementationType:implementationType];

    if (!originalImplementation) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"No stored implementation found for %@ in class %@",
                                              NSStringFromSelector(originalSelector), NSStringFromClass(targetClass)];
        return NO;
    }

    // Restore the original implementation
    method_setImplementation(originalMethod, originalImplementation);

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryInterception
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Successfully unswizzled %@ in class %@",
                                          NSStringFromSelector(originalSelector), NSStringFromClass(targetClass)];

    return YES;
}

+ (BOOL)class:(Class)cls
implementsSelector:(SEL)selector
 ofType:(WCImplementationType)implementationType {

    if (!cls || !selector) {
        return NO;
    }

    Class targetClass = [self classForImplementationType:cls implementationType:implementationType];
    return class_getInstanceMethod(targetClass, selector) != NULL;
}

+ (Class)classForImplementationType:(Class)cls
                 implementationType:(WCImplementationType)implementationType {

    if (!cls) {
        return nil;
    }

    switch (implementationType) {
        case WCImplementationTypeMethod:
            return cls;

        case WCImplementationTypeClassMethod:
            return object_getClass(cls);

        case WCImplementationTypeProperty:
            return cls;

        case WCImplementationTypeProtocol:
            return cls;

        default:
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                        category:WCLogCategoryInterception
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Unknown implementation type: %ld", (long)implementationType];
            return nil;
    }
}

+ (void)storeOriginalImplementation:(IMP)implementation
                           forClass:(Class)cls
                           selector:(SEL)selector
                 implementationType:(WCImplementationType)implementationType {

    if (!implementation || !cls || !selector) {
        return;
    }

    @synchronized(originalImplementations) {
        NSString *key = WCImplementationKeyForMethod(cls, selector, implementationType);
        originalImplementations[key] = [NSValue valueWithPointer:implementation];

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Stored original implementation for %@ in class %@",
                                              NSStringFromSelector(selector), NSStringFromClass(cls)];
    }
}

+ (IMP)originalImplementationForClass:(Class)cls
                             selector:(SEL)selector
                   implementationType:(WCImplementationType)implementationType {

    if (!cls || !selector) {
        return NULL;
    }

    IMP implementation = NULL;

    @synchronized(originalImplementations) {
        NSString *key = WCImplementationKeyForMethod(cls, selector, implementationType);
        NSValue *value = originalImplementations[key];

        if (value) {
            implementation = [value pointerValue];
        }
    }

    return implementation;
}

+ (void)clearStoredImplementations {
    @synchronized(originalImplementations) {
        [originalImplementations removeAllObjects];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:WCLogCategoryInterception
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cleared all stored method implementations"];
    }
}

#pragma mark - Private Methods

+ (BOOL)exchangeImplementations:(Method)originalMethod replacementMethod:(Method)replacementMethod {
    if (!originalMethod || !replacementMethod) {
        return NO;
    }

    method_exchangeImplementations(originalMethod, replacementMethod);
    return YES;
}

+ (BOOL)replaceImplementation:(Method)method withImplementation:(IMP)implementation {
    if (!method || !implementation) {
        return NO;
    }

    method_setImplementation(method, implementation);
    return YES;
}

@end
