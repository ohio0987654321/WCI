/**
 * @file runtime_utils.m
 * @brief Implementation of Objective-C runtime utilities for WindowControlInjector
 */

#import "runtime_utils.h"
#import "logger.h"

BOOL WCSwizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);

    if (!originalMethod || !swizzledMethod) {
        WCLogError(@"Failed to swizzle method %@ in class %@: methods not found",
                   NSStringFromSelector(originalSelector), NSStringFromClass(cls));
        return NO;
    }

    BOOL didAddMethod = class_addMethod(cls,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod(cls,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }

    WCLogDebug(@"Successfully swizzled method %@ with %@ in class %@",
               NSStringFromSelector(originalSelector),
               NSStringFromSelector(swizzledSelector),
               NSStringFromClass(cls));

    return YES;
}

BOOL WCSwizzleClassMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    Class metaClass = object_getClass(cls);
    return WCSwizzleMethod(metaClass, originalSelector, swizzledSelector);
}

BOOL WCAddMethod(Class cls, SEL selector, IMP implementation, const char *typeEncoding) {
    if (!cls || !selector || !implementation || !typeEncoding) {
        WCLogError(@"Failed to add method %@ to class %@: invalid arguments",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
        return NO;
    }

    BOOL success = class_addMethod(cls, selector, implementation, typeEncoding);

    if (success) {
        WCLogDebug(@"Successfully added method %@ to class %@",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
    } else {
        WCLogWarning(@"Failed to add method %@ to class %@: method already exists",
                    NSStringFromSelector(selector), NSStringFromClass(cls));
    }

    return success;
}

IMP WCReplaceMethod(Class cls, SEL selector, IMP implementation) {
    if (!cls || !selector || !implementation) {
        WCLogError(@"Failed to replace method %@ in class %@: invalid arguments",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
        return NULL;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        WCLogError(@"Failed to replace method %@ in class %@: method not found",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
        return NULL;
    }

    IMP originalImplementation = method_getImplementation(method);
    const char *typeEncoding = method_getTypeEncoding(method);

    class_replaceMethod(cls, selector, implementation, typeEncoding);

    WCLogDebug(@"Successfully replaced method %@ in class %@",
               NSStringFromSelector(selector), NSStringFromClass(cls));

    return originalImplementation;
}

IMP WCGetMethodImplementation(Class cls, SEL selector) {
    if (!cls || !selector) {
        WCLogError(@"Failed to get method implementation for %@ in class %@: invalid arguments",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
        return NULL;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        WCLogDebug(@"Method %@ not found in class %@",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
        return NULL;
    }

    return method_getImplementation(method);
}

const char *WCGetMethodTypeEncoding(Class cls, SEL selector) {
    if (!cls || !selector) {
        WCLogError(@"Failed to get method type encoding for %@ in class %@: invalid arguments",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
        return NULL;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        WCLogDebug(@"Method %@ not found in class %@",
                   NSStringFromSelector(selector), NSStringFromClass(cls));
        return NULL;
    }

    return method_getTypeEncoding(method);
}

BOOL WCClassImplementsMethod(Class cls, SEL selector) {
    if (!cls || !selector) {
        return NO;
    }

    return class_getInstanceMethod(cls, selector) != NULL;
}

objc_property_t WCGetProperty(Class cls, const char *propertyName) {
    if (!cls || !propertyName) {
        WCLogError(@"Failed to get property %s in class %@: invalid arguments",
                   propertyName, NSStringFromClass(cls));
        return NULL;
    }

    objc_property_t property = class_getProperty(cls, propertyName);
    if (!property) {
        WCLogDebug(@"Property %s not found in class %@",
                   propertyName, NSStringFromClass(cls));
    }

    return property;
}

SEL WCGetPropertyGetter(objc_property_t property) {
    if (!property) {
        WCLogError(@"Failed to get property getter: property is NULL");
        return NULL;
    }

    const char *attributes = property_getAttributes(property);
    const char *getterName = NULL;

    // Parse property attributes to find getter name
    // Format is T{type},V{ivar}[,G{getter}][,S{setter}][,{attributes}]
    char *getter = strstr(attributes, ",G");
    if (getter) {
        getter += 2; // Skip ",G"
        char *end = strstr(getter, ",");
        if (end) {
            // Null-terminate the getter name
            size_t len = end - getter;
            char *temp = malloc(len + 1);
            if (temp) {
                strncpy(temp, getter, len);
                temp[len] = '\0';
                getterName = temp;
            }
        } else {
            // Getter is at the end of the attributes string
            getterName = strdup(getter);
        }
    } else {
        // Default getter is the property name
        getterName = property_getName(property);
    }

    SEL result = sel_registerName(getterName);

    // Free the memory if we allocated it
    if (getter && getterName != property_getName(property)) {
        free((void *)getterName);
    }

    return result;
}

SEL WCGetPropertySetter(objc_property_t property) {
    if (!property) {
        WCLogError(@"Failed to get property setter: property is NULL");
        return NULL;
    }

    const char *attributes = property_getAttributes(property);
    const char *setterName = NULL;

    // Parse property attributes to find setter name
    char *setter = strstr(attributes, ",S");
    if (setter) {
        setter += 2; // Skip ",S"
        char *end = strstr(setter, ",");
        if (end) {
            // Null-terminate the setter name
            size_t len = end - setter;
            char *temp = malloc(len + 1);
            if (temp) {
                strncpy(temp, setter, len);
                temp[len] = '\0';
                setterName = temp;
            }
        } else {
            // Setter is at the end of the attributes string
            setterName = strdup(setter);
        }
    } else {
        // Default setter is "set" + capitalized property name + ":"
        const char *propertyName = property_getName(property);
        size_t len = strlen(propertyName);
        char *temp = malloc(len + 5); // "set" + property name + ":" + null terminator
        if (temp) {
            strcpy(temp, "set");
            temp[3] = toupper(propertyName[0]);
            strcpy(temp + 4, propertyName + 1);
            temp[len + 3] = ':';
            temp[len + 4] = '\0';
            setterName = temp;
        }
    }

    SEL result = sel_registerName(setterName);

    // Free the memory we allocated
    if (setterName) {
        free((void *)setterName);
    }

    return result;
}

const char *WCGetPropertyTypeEncoding(objc_property_t property) {
    if (!property) {
        WCLogError(@"Failed to get property type encoding: property is NULL");
        return NULL;
    }

    const char *attributes = property_getAttributes(property);

    // Type encoding is the first attribute, starting with 'T'
    if (attributes && attributes[0] == 'T') {
        return attributes + 1;
    }

    return NULL;
}

BOOL WCPropertyIsAtomic(objc_property_t property) {
    if (!property) {
        return YES; // Default is atomic
    }

    const char *attributes = property_getAttributes(property);

    // Check for ",N" which indicates nonatomic
    return strstr(attributes, ",N") == NULL;
}

BOOL WCPropertyIsReadWrite(objc_property_t property) {
    if (!property) {
        return YES; // Default is readwrite
    }

    const char *attributes = property_getAttributes(property);

    // Check for ",R" which indicates readonly
    return strstr(attributes, ",R") == NULL;
}
