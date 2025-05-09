/**
 * @file profile_manager.m
 * @brief Implementation of the profile management system for WindowControlInjector
 */

#import "profile_manager.h"
#import "../util/logger.h"

// Import profile headers
#import "../../profiles/invisible.h"
#import "../../profiles/stealth.h"
#import "../../profiles/unfocusable.h"
#import "../../profiles/click_through.h"
#import "../../profiles/direct_control.h"

@implementation WCProfileManager {
    NSMutableDictionary<NSString *, id<WCProfile>> *_profiles;
}

+ (instancetype)sharedManager {
    static WCProfileManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[WCProfileManager alloc] init];
    });

    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _profiles = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)registerProfile:(id<WCProfile>)profile {
    if (!profile) {
        WCLogError(@"Failed to register profile: profile is nil");
        return NO;
    }

    NSString *name = [profile name];
    if (!name) {
        WCLogError(@"Failed to register profile: profile name is nil");
        return NO;
    }

    @synchronized (self) {
        if (_profiles[name]) {
            WCLogWarning(@"Overwriting existing profile with name '%@'", name);
        }

        _profiles[name] = profile;
    }

    WCLogInfo(@"Registered profile: %@ - %@", name, [profile profileDescription]);
    return YES;
}

- (id<WCProfile>)profileWithName:(NSString *)name {
    if (!name) {
        WCLogError(@"Failed to get profile: name is nil");
        return nil;
    }

    id<WCProfile> profile = nil;

    @synchronized (self) {
        profile = _profiles[name];
    }

    if (!profile) {
        WCLogDebug(@"Profile with name '%@' not found", name);
    }

    return profile;
}

- (BOOL)hasProfileWithName:(NSString *)name {
    if (!name) {
        return NO;
    }

    BOOL hasProfile = NO;

    @synchronized (self) {
        hasProfile = _profiles[name] != nil;
    }

    return hasProfile;
}

- (BOOL)unregisterProfileWithName:(NSString *)name {
    if (!name) {
        WCLogError(@"Failed to unregister profile: name is nil");
        return NO;
    }

    BOOL success = NO;

    @synchronized (self) {
        if (_profiles[name]) {
            [_profiles removeObjectForKey:name];
            success = YES;
        }
    }

    if (success) {
        WCLogInfo(@"Unregistered profile: %@", name);
    } else {
        WCLogDebug(@"Failed to unregister profile with name '%@': profile not found", name);
    }

    return success;
}

- (NSArray<id<WCProfile>> *)allProfiles {
    NSArray<id<WCProfile>> *profiles = nil;

    @synchronized (self) {
        profiles = [_profiles allValues];
    }

    return profiles;
}

- (BOOL)clearAllProfiles {
    @synchronized (self) {
        [_profiles removeAllObjects];
    }

    WCLogInfo(@"Cleared all profiles");
    return YES;
}

- (BOOL)initializeWithBuiltInProfiles {
    WCLogInfo(@"Initializing with built-in profiles");

    // Register built-in profiles
    BOOL success = YES;

    success &= [self registerProfile:[WCInvisibleProfile profile]];
    success &= [self registerProfile:[WCStealthProfile profile]];
    success &= [self registerProfile:[WCUnfocusableProfile profile]];
    success &= [self registerProfile:[WCClickThroughProfile profile]];
    success &= [self registerProfile:[WCDirectControlProfile profile]];

    if (success) {
        WCLogInfo(@"Successfully registered built-in profiles");
    } else {
        WCLogError(@"Failed to register one or more built-in profiles");
    }

    return success;
}

@end

// C function wrappers for the public API
BOOL WCRegisterProfile(id<WCProfile> profile) {
    return [[WCProfileManager sharedManager] registerProfile:profile];
}

id<WCProfile> WCGetProfile(NSString *name) {
    return [[WCProfileManager sharedManager] profileWithName:name];
}

NSArray<id<WCProfile>> *WCGetAllProfiles(void) {
    return [[WCProfileManager sharedManager] allProfiles];
}

BOOL WCIsProfileRegistered(NSString *name) {
    return [[WCProfileManager sharedManager] hasProfileWithName:name];
}
