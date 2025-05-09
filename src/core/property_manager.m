/**
 * @file property_manager.m
 * @brief Implementation of the property management system for WindowControlInjector
 */

#import "property_manager.h"
#import "../../include/profiles.h"
#import "../util/logger.h"
#import <objc/runtime.h>

@implementation WCPropertyManager {
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *_overrides;
    dispatch_queue_t _queue;
}

+ (instancetype)sharedManager {
    static WCPropertyManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[WCPropertyManager alloc] init];
    });

    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _overrides = [NSMutableDictionary dictionary];
        _queue = dispatch_queue_create("com.windowcontrolinjector.propertymanager", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (BOOL)applyProfile:(NSString *)profileName {
    if (!profileName) {
        WCLogError(@"Failed to apply profile: profile name is nil");
        return NO;
    }

    id<WCProfile> profile = WCGetProfile(profileName);
    if (!profile) {
        WCLogError(@"Failed to apply profile '%@': profile not found", profileName);
        return NO;
    }

    WCLogInfo(@"Applying profile: %@ - %@", [profile name], [profile profileDescription]);

    // Apply dependencies first
    NSArray<NSString *> *dependencies = [profile dependencies];
    if (dependencies) {
        for (NSString *dependencyName in dependencies) {
            BOOL success = [self applyProfile:dependencyName];
            if (!success) {
                WCLogWarning(@"Failed to apply dependency '%@' for profile '%@'", dependencyName, profileName);
            }
        }
    }

    // Apply the profile's property overrides
    NSDictionary *profileOverrides = [profile propertyOverrides];
    return [self applyPropertyOverrides:profileOverrides];
}

- (BOOL)setOverrideValue:(id)value forProperty:(NSString *)propertyName onClass:(NSString *)className {
    if (!value || !propertyName || !className) {
        WCLogError(@"Failed to set override: invalid arguments");
        return NO;
    }

    WCLogDebug(@"Setting override for %@.%@ to %@", className, propertyName, value);

    __block BOOL success = YES;

    dispatch_barrier_async(_queue, ^{
        NSMutableDictionary *classOverrides = self->_overrides[className];
        if (!classOverrides) {
            classOverrides = [NSMutableDictionary dictionary];
            self->_overrides[className] = classOverrides;
        }

        classOverrides[propertyName] = value;
    });

    return success;
}

- (id)overrideValueForProperty:(NSString *)propertyName onClass:(NSString *)className {
    if (!propertyName || !className) {
        WCLogError(@"Failed to get override: invalid arguments");
        return nil;
    }

    __block id value = nil;

    dispatch_sync(_queue, ^{
        NSMutableDictionary *classOverrides = self->_overrides[className];
        if (classOverrides) {
            value = classOverrides[propertyName];
        }
    });

    return value;
}

- (BOOL)hasOverrideForProperty:(NSString *)propertyName onClass:(NSString *)className {
    return [self overrideValueForProperty:propertyName onClass:className] != nil;
}

- (BOOL)removeOverrideForProperty:(NSString *)propertyName onClass:(NSString *)className {
    if (!propertyName || !className) {
        WCLogError(@"Failed to remove override: invalid arguments");
        return NO;
    }

    __block BOOL success = NO;

    dispatch_barrier_async(_queue, ^{
        NSMutableDictionary *classOverrides = self->_overrides[className];
        if (classOverrides && classOverrides[propertyName]) {
            [classOverrides removeObjectForKey:propertyName];
            success = YES;

            // If the class has no more overrides, remove it from the dictionary
            if (classOverrides.count == 0) {
                [self->_overrides removeObjectForKey:className];
            }
        }
    });

    return success;
}

- (BOOL)applyPropertyOverrides:(NSDictionary *)overrides {
    if (!overrides) {
        WCLogError(@"Failed to apply property overrides: overrides dictionary is nil");
        return NO;
    }

    __block BOOL success = YES;

    // Iterate through each class in the overrides dictionary
    [overrides enumerateKeysAndObjectsUsingBlock:^(NSString *className, NSDictionary *propertyOverrides, BOOL *stop) {
        // Check that the properties dictionary is valid
        if (![propertyOverrides isKindOfClass:[NSDictionary class]]) {
            WCLogError(@"Failed to apply property overrides for class '%@': invalid property overrides format", className);
            success = NO;
            return;
        }

        // Iterate through each property in the properties dictionary
        [propertyOverrides enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, id value, BOOL *innerStop) {
            BOOL setSuccess = [self setOverrideValue:value forProperty:propertyName onClass:className];
            if (!setSuccess) {
                WCLogWarning(@"Failed to set override for %@.%@", className, propertyName);
                success = NO;
            }
        }];
    }];

    return success;
}

- (BOOL)clearAllOverrides {
    dispatch_barrier_async(_queue, ^{
        [self->_overrides removeAllObjects];
    });

    return YES;
}

- (NSDictionary *)allOverrides {
    __block NSDictionary *overridesCopy = nil;

    dispatch_sync(_queue, ^{
        // Create a deep copy of the overrides dictionary
        NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithCapacity:self->_overrides.count];
        for (NSString *className in self->_overrides) {
            copy[className] = [self->_overrides[className] copy];
        }
        overridesCopy = [copy copy];
    });

    return overridesCopy;
}

- (NSDictionary *)overridesForClass:(NSString *)className {
    if (!className) {
        return nil;
    }

    __block NSDictionary *classOverridesCopy = nil;

    dispatch_sync(_queue, ^{
        NSMutableDictionary *classOverrides = self->_overrides[className];
        if (classOverrides) {
            classOverridesCopy = [classOverrides copy];
        }
    });

    return classOverridesCopy;
}

@end

// C function wrappers for the public API
BOOL WCSetOverrideValue(id value, NSString *propertyName, NSString *className) {
    return [[WCPropertyManager sharedManager] setOverrideValue:value forProperty:propertyName onClass:className];
}

id WCGetOverrideValue(NSString *propertyName, NSString *className) {
    return [[WCPropertyManager sharedManager] overrideValueForProperty:propertyName onClass:className];
}

BOOL WCApplyProfile(NSString *profileName) {
    return [[WCPropertyManager sharedManager] applyProfile:profileName];
}
