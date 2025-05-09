/**
 * @file injector.m
 * @brief Implementation of the injection mechanism for WindowControlInjector
 */

#import "../../include/injector.h"
#import "../../include/profiles.h"
#import "../../include/window_control.h"
#import "../util/logger.h"
#import "profile_manager.h"
#import "property_manager.h"

// Static variables
static NSString *gDylibPath = nil;

@implementation WCInjector

+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                 withProfiles:(NSArray<NSString *> *)profileNames
                        error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInvalidArguments
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is required"}];
        }
        return NO;
    }

    // Check if application exists
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:applicationPath isDirectory:&isDirectory] || !isDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorApplicationNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Application not found at path: %@", applicationPath]}];
        }
        return NO;
    }

    // Get dylib path
    NSString *dylibPath = [self findDylibPath];
    if (!dylibPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not find WindowControlInjector dylib"}];
        }
        return NO;
    }

    // Create task to launch application with injected dylib
    NSTask *task = [NSTask new];
    [task setLaunchPath:@"/usr/bin/open"];

    // Prepare environment variables for injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    // Set DYLD_INSERT_LIBRARIES to inject the dylib
    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;

    // If profiles are provided, pass them as an environment variable
    if (profileNames && profileNames.count > 0) {
        NSString *profilesString = [profileNames componentsJoinedByString:@","];
        env[@"WCI_PROFILES"] = profilesString;
        WCLogInfo(@"Injecting profiles: %@", profilesString);
    }

    [task setEnvironment:env];

    // Set arguments to open the application
    [task setArguments:@[@"-a", applicationPath]];

    // Launch the application
    @try {
        [task launch];
        WCLogInfo(@"Successfully injected dylib into application: %@", applicationPath);
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to launch application: %@", exception.reason]}];
        }
        return NO;
    }
}

+ (BOOL)injectIntoApplication:(NSString *)applicationPath
        withPropertyOverrides:(NSDictionary *)overrides
                        error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInvalidArguments
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is required"}];
        }
        return NO;
    }

    // Check if application exists
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:applicationPath isDirectory:&isDirectory] || !isDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorApplicationNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Application not found at path: %@", applicationPath]}];
        }
        return NO;
    }

    // Get dylib path
    NSString *dylibPath = [self findDylibPath];
    if (!dylibPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not find WindowControlInjector dylib"}];
        }
        return NO;
    }

    // Create task to launch application with injected dylib
    NSTask *task = [NSTask new];
    [task setLaunchPath:@"/usr/bin/open"];

    // Prepare environment variables for injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    // Set DYLD_INSERT_LIBRARIES to inject the dylib
    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;

    // If overrides are provided, serialize them and pass as an environment variable
    if (overrides && overrides.count > 0) {
        NSError *jsonError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:overrides
                                                           options:0
                                                             error:&jsonError];
        if (jsonError || !jsonData) {
            if (error) {
                *error = [NSError errorWithDomain:WCErrorDomain
                                             code:WCErrorInvalidArguments
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize property overrides to JSON"}];
            }
            return NO;
        }

        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        env[@"WCI_OVERRIDES"] = jsonString;
        WCLogInfo(@"Injecting property overrides: %@", jsonString);
    }

    [task setEnvironment:env];

    // Set arguments to open the application
    [task setArguments:@[@"-a", applicationPath]];

    // Launch the application
    @try {
        [task launch];
        WCLogInfo(@"Successfully injected dylib into application: %@", applicationPath);
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to launch application: %@", exception.reason]}];
        }
        return NO;
    }
}

+ (NSTask *)launchApplication:(NSString *)applicationPath
                 withProfiles:(NSArray<NSString *> *)profileNames
                    arguments:(NSArray<NSString *> *)arguments
                        error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInvalidArguments
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is required"}];
        }
        return nil;
    }

    // Check if application exists
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:applicationPath isDirectory:&isDirectory] || !isDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorApplicationNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Application not found at path: %@", applicationPath]}];
        }
        return nil;
    }

    // Get dylib path
    NSString *dylibPath = [self findDylibPath];
    if (!dylibPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not find WindowControlInjector dylib"}];
        }
        return nil;
    }

    // Find the executable within the application bundle
    NSString *executablePath = nil;
    NSBundle *appBundle = [NSBundle bundleWithPath:applicationPath];
    if (appBundle) {
        executablePath = [appBundle executablePath];
    }

    if (!executablePath) {
        // Fallback method to find executable
        NSString *contentsPath = [applicationPath stringByAppendingPathComponent:@"Contents"];
        NSString *infoPlistPath = [contentsPath stringByAppendingPathComponent:@"Info.plist"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:infoPlistPath]) {
            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
            NSString *executableName = infoPlist[@"CFBundleExecutable"];

            if (executableName) {
                executablePath = [contentsPath stringByAppendingPathComponent:@"MacOS"];
                executablePath = [executablePath stringByAppendingPathComponent:executableName];
            }
        }
    }

    if (!executablePath || ![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorApplicationNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not find executable in application: %@", applicationPath]}];
        }
        return nil;
    }

    // Create task to launch application with injected dylib
    NSTask *task = [NSTask new];
    [task setLaunchPath:executablePath];

    // Prepare environment variables for injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    // Set DYLD_INSERT_LIBRARIES to inject the dylib
    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;

    // If profiles are provided, pass them as an environment variable
    if (profileNames && profileNames.count > 0) {
        NSString *profilesString = [profileNames componentsJoinedByString:@","];
        env[@"WCI_PROFILES"] = profilesString;
        WCLogInfo(@"Injecting profiles: %@", profilesString);
    }

    [task setEnvironment:env];

    // Set arguments if provided
    if (arguments && arguments.count > 0) {
        [task setArguments:arguments];
    }

    // Launch the application
    @try {
        [task launch];
        WCLogInfo(@"Successfully launched application with injected dylib: %@", applicationPath);
        return task;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to launch application: %@", exception.reason]}];
        }
        return nil;
    }
}

+ (NSTask *)launchApplication:(NSString *)applicationPath
        withPropertyOverrides:(NSDictionary *)overrides
                    arguments:(NSArray<NSString *> *)arguments
                        error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInvalidArguments
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is required"}];
        }
        return nil;
    }

    // Check if application exists
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:applicationPath isDirectory:&isDirectory] || !isDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorApplicationNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Application not found at path: %@", applicationPath]}];
        }
        return nil;
    }

    // Get dylib path
    NSString *dylibPath = [self findDylibPath];
    if (!dylibPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not find WindowControlInjector dylib"}];
        }
        return nil;
    }

    // Find the executable within the application bundle
    NSString *executablePath = nil;
    NSBundle *appBundle = [NSBundle bundleWithPath:applicationPath];
    if (appBundle) {
        executablePath = [appBundle executablePath];
    }

    if (!executablePath) {
        // Fallback method to find executable
        NSString *contentsPath = [applicationPath stringByAppendingPathComponent:@"Contents"];
        NSString *infoPlistPath = [contentsPath stringByAppendingPathComponent:@"Info.plist"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:infoPlistPath]) {
            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
            NSString *executableName = infoPlist[@"CFBundleExecutable"];

            if (executableName) {
                executablePath = [contentsPath stringByAppendingPathComponent:@"MacOS"];
                executablePath = [executablePath stringByAppendingPathComponent:executableName];
            }
        }
    }

    if (!executablePath || ![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorApplicationNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not find executable in application: %@", applicationPath]}];
        }
        return nil;
    }

    // Create task to launch application with injected dylib
    NSTask *task = [NSTask new];
    [task setLaunchPath:executablePath];

    // Prepare environment variables for injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    // Set DYLD_INSERT_LIBRARIES to inject the dylib
    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;

    // If overrides are provided, serialize them and pass as an environment variable
    if (overrides && overrides.count > 0) {
        NSError *jsonError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:overrides
                                                           options:0
                                                             error:&jsonError];
        if (jsonError || !jsonData) {
            if (error) {
                *error = [NSError errorWithDomain:WCErrorDomain
                                             code:WCErrorInvalidArguments
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize property overrides to JSON"}];
            }
            return nil;
        }

        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        env[@"WCI_OVERRIDES"] = jsonString;
        WCLogInfo(@"Injecting property overrides: %@", jsonString);
    }

    [task setEnvironment:env];

    // Set arguments if provided
    if (arguments && arguments.count > 0) {
        [task setArguments:arguments];
    }

    // Launch the application
    @try {
        [task launch];
        WCLogInfo(@"Successfully launched application with injected dylib: %@", applicationPath);
        return task;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:WCErrorDomain
                                         code:WCErrorInjectionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to launch application: %@", exception.reason]}];
        }
        return nil;
    }
}

+ (NSString *)findDylibPath {
    // If a custom path was set, use that
    if (gDylibPath) {
        return gDylibPath;
    }

    // Try to find the dylib in known locations
    NSArray<NSString *> *searchLocations = @[
        // Same directory as the current executable
        [[NSBundle mainBundle] bundlePath],
        [[NSBundle mainBundle] resourcePath],
        [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"lib"],

        // User's Application Support directory
        [NSString stringWithFormat:@"%@/Library/Application Support/WindowControlInjector",
         NSHomeDirectory()],

        // System Application Support directory
        @"/Library/Application Support/WindowControlInjector"
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSString *location in searchLocations) {
        NSString *dylibPath = [location stringByAppendingPathComponent:@"libwindow_control.dylib"];
        if ([fileManager fileExistsAtPath:dylibPath]) {
            return dylibPath;
        }
    }

    // Dylib not found
    WCLogError(@"Failed to find WindowControlInjector dylib");
    return nil;
}

+ (void)setDylibPath:(NSString *)path {
    gDylibPath = [path copy];
}

@end

// Dylib initialization function that will be called when the library is loaded
__attribute__((constructor))
static void initialize(void) {
    WCInitialize();

    // Check for profiles in environment variables
    NSString *profilesString = [[[NSProcessInfo processInfo] environment] objectForKey:@"WCI_PROFILES"];
    if (profilesString) {
        NSArray<NSString *> *profiles = [profilesString componentsSeparatedByString:@","];
        for (NSString *profileName in profiles) {
            WCApplyProfile(profileName);
        }
    }

    // Check for property overrides in environment variables
    NSString *overridesString = [[[NSProcessInfo processInfo] environment] objectForKey:@"WCI_OVERRIDES"];
    if (overridesString) {
        NSError *jsonError = nil;
        NSData *jsonData = [overridesString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *overrides = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                  options:0
                                                                    error:&jsonError];
        if (!jsonError && overrides) {
            [[WCPropertyManager sharedManager] applyPropertyOverrides:overrides];
        } else {
            WCLogError(@"Failed to parse property overrides from environment: %@", jsonError);
        }
    }
}

// C function wrappers for the public API
BOOL WCInjectIntoApplication(NSString *applicationPath, NSArray<NSString *> *profileNames, NSError **error) {
    return [WCInjector injectIntoApplication:applicationPath withProfiles:profileNames error:error];
}

BOOL WCInjectIntoApplicationWithOverrides(NSString *applicationPath, NSDictionary *overrides, NSError **error) {
    return [WCInjector injectIntoApplication:applicationPath withPropertyOverrides:overrides error:error];
}

NSString *WCGetVersion(void) {
    return [NSString stringWithUTF8String:WC_VERSION_STRING];
}

NSString *WCGetBuildDate(void) {
#ifdef BUILD_DATE
    return [NSString stringWithUTF8String:BUILD_DATE];
#else
    return @"Development Build";
#endif
}

BOOL WCInitialize(void) {
    // Initialize the logger
    WCSetLoggingEnabled(YES);
    WCSetLogLevel(WCLogLevelInfo);

    WCLogInfo(@"WindowControlInjector v%@ initializing...", WCGetVersion());

    // Initialize profile manager with built-in profiles
    [[WCProfileManager sharedManager] initializeWithBuiltInProfiles];

    return YES;
}
