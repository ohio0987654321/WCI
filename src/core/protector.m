/**
 * @file protector.m
 * @brief Implementation of core protection functionality for WindowControlInjector
 */

#import "protector.h"
#import "../util/logger.h"
#import "../interceptors/nswindow_interceptor.h"
#import "../interceptors/nsapplication_interceptor.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <AppKit/AppKit.h>

// Error domain
NSString *const WCProtectorErrorDomain = @"com.windowcontrolinjector.protector";

@implementation WCProtector

/**
 * Apply all protection features to the specified application
 */
+ (BOOL)protectApplication:(NSString *)applicationPath error:(NSError **)error {
    // Add direct console output for critical diagnostics
    printf("[WindowControlInjector] Starting application protection process\n");

    if (!applicationPath) {
        printf("[WindowControlInjector] ERROR: Application path is nil\n");
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:100
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is nil"}];
        }
        return NO;
    }

    printf("[WindowControlInjector] Protecting application: %s\n", [applicationPath UTF8String]);
    WCLogInfo(@"Applying protection to application: %@", applicationPath);

    // Verify the application exists before proceeding
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:applicationPath]) {
        printf("[WindowControlInjector] ERROR: Application not found at path: %s\n", [applicationPath UTF8String]);
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:101
                                     userInfo:@{NSLocalizedDescriptionKey:
                                               [NSString stringWithFormat:@"Application not found at path: %@", applicationPath]}];
        }
        return NO;
    }

    @try {
        // Find the injector dylib path
        NSString *dylibPath = [self findInjectorDylibPath];
        if (!dylibPath) {
            printf("[WindowControlInjector] ERROR: Couldn't find injector dylib\n");
            if (error) {
                *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                             code:102
                                         userInfo:@{NSLocalizedDescriptionKey: @"Couldn't find injector dylib"}];
            }
            return NO;
        }

        // Verify the dylib exists and is readable
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:dylibPath]) {
            printf("[WindowControlInjector] ERROR: Dylib not found at path: %s\n", [dylibPath UTF8String]);
            if (error) {
                *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                             code:103
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:@"Dylib not found at path: %@", dylibPath]}];
            }
            return NO;
        }

        printf("[WindowControlInjector] Using dylib: %s\n", [dylibPath UTF8String]);
        WCLogInfo(@"Using dylib: %@", dylibPath);

        // Create application URL
        NSURL *appURL = [NSURL fileURLWithPath:applicationPath];
        printf("[WindowControlInjector] Application URL: %s\n", [appURL.absoluteString UTF8String]);

        // Set up environment variables for the new process
        NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
        env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;
        printf("[WindowControlInjector] Setting DYLD_INSERT_LIBRARIES=%s\n", [dylibPath UTF8String]);

        // For macOS 11.0 and later, use the new API
        if (@available(macOS 11.0, *)) {
            printf("[WindowControlInjector] Using modern macOS 11.0+ launch API\n");

            // Create configuration with newer API
            NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
            [configuration setEnvironment:env];
            [configuration setCreatesNewApplicationInstance:YES];

            // Launch the application and use dispatch semaphore to wait for completion
            printf("[WindowControlInjector] Launching application...\n");
            WCLogInfo(@"Launching application using NSWorkspace with modern API...");

            // Create a semaphore to wait for the completion handler
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            __block BOOL launchSuccess = NO;
            __block NSError *launchError = nil;

            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                               configuration:configuration
                                           completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable appError) {
                if (app) {
                    printf("[WindowControlInjector] Application launched successfully\n");
                    WCLogInfo(@"Application launched successfully with protection");
                    launchSuccess = YES;
                } else {
                    printf("[WindowControlInjector] ERROR: Failed to launch application: %s\n",
                          appError ? [appError.localizedDescription UTF8String] : "Unknown error");
                    WCLogError(@"Failed to launch application: %@", appError ? [appError localizedDescription] : @"Unknown error");
                    launchError = appError;
                    launchSuccess = NO;
                }
                dispatch_semaphore_signal(semaphore);
            }];

            // Wait for the launch to complete (with extended timeout - 15 seconds should be sufficient for most apps)
            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC);
            if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
                printf("[WindowControlInjector] ERROR: Timeout waiting for application launch\n");
                if (error) {
                    *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                                 code:104
                                             userInfo:@{NSLocalizedDescriptionKey: @"Timeout waiting for application launch"}];
                }
                return NO;
            }

            // Handle errors from completion handler
            if (!launchSuccess) {
                if (error && launchError) {
                    *error = launchError;
                } else if (error) {
                    *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                                 code:105
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to launch application"}];
                }
                return NO;
            }

            return YES;
        } else {
            // For older macOS versions, use the deprecated API but fix the type issue
            printf("[WindowControlInjector] Using legacy launch API for older macOS versions\n");
            WCLogInfo(@"Launching application using NSWorkspace with legacy API...");
            NSError *launchError = nil;
            NSRunningApplication *app = [[NSWorkspace sharedWorkspace]
                                        launchApplicationAtURL:appURL
                                                      options:NSWorkspaceLaunchNewInstance
                                               configuration:@{NSWorkspaceLaunchConfigurationEnvironment: env}
                                                       error:&launchError];

            if (app) {
                printf("[WindowControlInjector] Application launched successfully\n");
                WCLogInfo(@"Application launched successfully with protection");
                return YES;
            } else {
                printf("[WindowControlInjector] ERROR: Failed to launch application: %s\n",
                       launchError ? [launchError.localizedDescription UTF8String] : "Unknown error");

                if (error) {
                    *error = launchError ? launchError : [NSError errorWithDomain:WCProtectorErrorDomain
                                                                            code:106
                                                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to launch application"}];
                }
                WCLogError(@"Failed to launch application: %@", launchError ? [launchError localizedDescription] : @"Unknown error");
                return NO;
            }
        }
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:102
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Failed to launch application",
                                         NSLocalizedFailureReasonErrorKey: [exception reason]
                                     }];
        }

        WCLogError(@"Failed to launch application: %@", exception);
        return NO;
    }
}

/**
 * Process existing windows when initializing
 */
+ (void)processExistingWindows {
    // Apply settings to any existing windows
    NSApplication *app = [NSApplication sharedApplication];

    WCLogInfo(@"Processing existing windows in the application");

    // Process all windows
    for (NSWindow *window in [app windows]) {
        WCLogInfo(@"Found existing window: %@", window);
        // Window settings are controlled by the interceptors
    }

    // Set up a notification observer for new windows
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(windowDidBecomeVisible:)
                                                 name:NSWindowDidExposeNotification
                                               object:nil];
}

/**
 * Handle window visibility notifications
 */
+ (void)windowDidBecomeVisible:(NSNotification *)notification {
    NSWindow *window = notification.object;
    if ([window isKindOfClass:[NSWindow class]]) {
        WCLogInfo(@"New window became visible: %@", window);
        // Window settings are controlled by the interceptors
    }
}

/**
 * Initialize the WindowControlInjector
 */
+ (BOOL)initialize {
    WCLogInfo(@"Initializing WindowControlInjector");

    // Install interceptors
    BOOL success = [WCNSWindowInterceptor install];
    success &= [WCNSApplicationInterceptor install];

    // Process existing windows if we're running inside an injected application
    // This won't do anything when running as the injector
    [self processExistingWindows];

    WCLogInfo(@"WindowControlInjector initialized %@", success ? @"successfully" : @"with errors");

    return success;
}

/**
 * Find the path to the injector dylib
 */
+ (NSString *)findInjectorDylibPath {
    printf("[WindowControlInjector] Searching for injector dylib...\n");

    // Try to find the dylib relative to the executable
    NSString *executablePath = [[NSProcessInfo processInfo] arguments][0];
    NSString *executableDir = [executablePath stringByDeletingLastPathComponent];

    printf("[WindowControlInjector] Executable directory: %s\n", [executableDir UTF8String]);

    // Check common locations relative to executable
    NSArray *possiblePaths = @[
        // Check directly in the same directory as the executable
        [executableDir stringByAppendingPathComponent:@"libwindowcontrolinjector.dylib"],

        // Check in relative locations
        [executableDir stringByAppendingPathComponent:@"../lib/libwindowcontrolinjector.dylib"],
        [[executableDir stringByAppendingPathComponent:@".."] stringByAppendingPathComponent:@"libwindowcontrolinjector.dylib"],

        // Check in standard locations
        @"/usr/local/lib/libwindowcontrolinjector.dylib",

        // Check in build directory relative to executable
        [executableDir stringByAppendingPathComponent:@"../build/libwindowcontrolinjector.dylib"],
        [[executableDir stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"build/libwindowcontrolinjector.dylib"],

        // Use absolute path based on current directory structure
        [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:@"build/libwindowcontrolinjector.dylib"]
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Print current working directory for diagnosis
    printf("[WindowControlInjector] Current working directory: %s\n",
           [[[NSFileManager defaultManager] currentDirectoryPath] UTF8String]);

    for (NSString *path in possiblePaths) {
        printf("[WindowControlInjector] Checking path: %s\n", [path UTF8String]);
        if ([fileManager fileExistsAtPath:path]) {
            printf("[WindowControlInjector] Found dylib at: %s\n", [path UTF8String]);
            return path;
        }
    }

    // If we can't find it in common locations, try to get the path from the loaded dylibs
    printf("[WindowControlInjector] Checking loaded dylibs...\n");
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        NSString *imagePath = [NSString stringWithUTF8String:path];
        if ([imagePath containsString:@"windowcontrolinjector"]) {
            printf("[WindowControlInjector] Found dylib in loaded images: %s\n", [imagePath UTF8String]);
            return imagePath;
        }
    }

    // If we're already running as the dylib, get our own path using a known function in this file
    printf("[WindowControlInjector] Attempting to find own dylib path...\n");
    Dl_info info;
    if (dladdr((const void *)WCProtectApplication, &info)) {
        NSString *path = [NSString stringWithUTF8String:info.dli_fname];
        if ([path containsString:@"windowcontrolinjector"]) {
            printf("[WindowControlInjector] Found own dylib path: %s\n", [path UTF8String]);
            return path;
        }
    }

    printf("[WindowControlInjector] ERROR: Could not find injector dylib\n");
    WCLogError(@"Could not find injector dylib");
    return nil;
}

/**
 * Set the logging level
 */
+ (void)setLogLevel:(NSInteger)logLevel {
    // Map integer level to WCLogLevel enum
    WCLogLevel level;
    switch (logLevel) {
        case 0:
            level = WCLogLevelError;
            break;
        case 1:
            level = WCLogLevelWarning;
            break;
        case 2:
            level = WCLogLevelInfo;
            break;
        case 3:
            level = WCLogLevelDebug;
            break;
        default:
            level = WCLogLevelWarning; // Default
            break;
    }

    // Set log level using the WCLogger class
    [[WCLogger sharedLogger] setLogLevel:level];
}

/**
 * Apply specific profiles to the application
 */
+ (BOOL)protectApplicationWithProfiles:(NSString *)applicationPath
                           withProfiles:(NSArray<NSString *> *)profiles
                                 error:(NSError **)error {
    // Add direct console output for diagnostics
    printf("[WindowControlInjector] Starting application protection with profiles\n");

    if (!applicationPath) {
        printf("[WindowControlInjector] ERROR: Application path is nil\n");
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:100
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is nil"}];
        }
        return NO;
    }

    if (!profiles || profiles.count == 0) {
        printf("[WindowControlInjector] WARNING: No profiles specified, using default protection\n");
        return [self protectApplication:applicationPath error:error];
    }

    printf("[WindowControlInjector] Protecting application with %lu profiles: %s\n",
           (unsigned long)profiles.count, [[profiles componentsJoinedByString:@", "] UTF8String]);
    WCLogInfo(@"Applying protection to application with profiles: %@", [profiles componentsJoinedByString:@", "]);

    // Store the profiles in the environment so they can be accessed by the injected dylib
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    NSString *profilesStr = [profiles componentsJoinedByString:@","];
    env[@"WC_PROFILES"] = profilesStr;

    // Call the standard protection method which will handle the launch
    // The injected dylib will read the WC_PROFILES environment variable
    return [self protectApplication:applicationPath error:error];
}

/**
 * Apply specific property overrides to the application
 */
+ (BOOL)protectApplicationWithProperties:(NSString *)applicationPath
                          withProperties:(NSDictionary *)properties
                                   error:(NSError **)error {
    // Add direct console output for diagnostics
    printf("[WindowControlInjector] Starting application protection with property overrides\n");

    if (!applicationPath) {
        printf("[WindowControlInjector] ERROR: Application path is nil\n");
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:100
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is nil"}];
        }
        return NO;
    }

    if (!properties || properties.count == 0) {
        printf("[WindowControlInjector] WARNING: No property overrides specified, using default protection\n");
        return [self protectApplication:applicationPath error:error];
    }

    printf("[WindowControlInjector] Protecting application with property overrides\n");
    WCLogInfo(@"Applying protection to application with property overrides: %@", properties);

    // Convert properties dictionary to JSON string and store in environment
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:properties
                                                      options:0
                                                        error:&jsonError];
    if (!jsonData) {
        printf("[WindowControlInjector] ERROR: Failed to serialize property overrides to JSON\n");
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:107
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize property overrides"}];
        }
        return NO;
    }

    NSString *propertiesJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"WC_PROPERTY_OVERRIDES"] = propertiesJson;

    // Call the standard protection method which will handle the launch
    // The injected dylib will read the WC_PROPERTY_OVERRIDES environment variable
    return [self protectApplication:applicationPath error:error];
}

@end

// C function wrappers for the public API
BOOL WCProtectApplication(NSString *applicationPath, NSError **error) {
    return [WCProtector protectApplication:applicationPath error:error];
}

BOOL WCProtectApplicationWithProfiles(NSString *applicationPath, NSArray<NSString *> *profiles, NSError **error) {
    return [WCProtector protectApplicationWithProfiles:applicationPath withProfiles:profiles error:error];
}

BOOL WCProtectApplicationWithProperties(NSString *applicationPath, NSDictionary *properties, NSError **error) {
    return [WCProtector protectApplicationWithProperties:applicationPath withProperties:properties error:error];
}

BOOL WCInitialize(void) {
    return [WCProtector initialize];
}
