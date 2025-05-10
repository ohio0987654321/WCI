/**
 * @file protector.m
 * @brief Implementation of core protection functionality for WindowControlInjector
 */

#import "protector.h"
#import "../util/logger.h"
#import "../util/error_manager.h"
#import "../util/configuration_manager.h"
#import "../util/path_resolver.h"
#import "../interceptors/interceptor_registry.h"
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
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Launch"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Applying protection to application: %@", applicationPath];

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
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Launch"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Application not found at path: %@", applicationPath];
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
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Injection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Using dylib: %@", dylibPath];

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
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"Launch"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Launching application using NSWorkspace with modern API..."];

            // Create a semaphore to wait for the completion handler
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            __block BOOL launchSuccess = NO;
            __block NSError *launchError = nil;

            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                               configuration:configuration
                                           completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable appError) {
                if (app) {
                    printf("[WindowControlInjector] Application launched successfully\n");
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                 category:@"Launch"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Application launched successfully with protection"];
                    launchSuccess = YES;
                } else {
                    printf("[WindowControlInjector] ERROR: Failed to launch application: %s\n",
                          appError ? [appError.localizedDescription UTF8String] : "Unknown error");
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                                 category:@"Launch"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Failed to launch application: %@", appError ? [appError localizedDescription] : @"Unknown error"];
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
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"Launch"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Launching application using NSWorkspace with legacy API..."];
            NSError *launchError = nil;
            NSRunningApplication *app = [[NSWorkspace sharedWorkspace]
                                        launchApplicationAtURL:appURL
                                                      options:NSWorkspaceLaunchNewInstance
                                               configuration:@{NSWorkspaceLaunchConfigurationEnvironment: env}
                                                       error:&launchError];

            if (app) {
                printf("[WindowControlInjector] Application launched successfully\n");
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                             category:@"Launch"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Application launched successfully with protection"];
                return YES;
            } else {
                printf("[WindowControlInjector] ERROR: Failed to launch application: %s\n",
                       launchError ? [launchError.localizedDescription UTF8String] : "Unknown error");

                if (error) {
                    *error = launchError ? launchError : [NSError errorWithDomain:WCProtectorErrorDomain
                                                                            code:106
                                                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to launch application"}];
                }
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                             category:@"Launch"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Failed to launch application: %@", launchError ? [launchError localizedDescription] : @"Unknown error"];
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

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Launch"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to launch application: %@", exception];
        return NO;
    }
}

/**
 * Process existing windows when initializing
 */
+ (void)processExistingWindows {
    // Apply settings to any existing windows
    NSApplication *app = [NSApplication sharedApplication];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Window"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Processing existing windows in the application"];

    // Process all windows
    for (NSWindow *window in [app windows]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Found existing window: %@", window];
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
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Window"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"New window became visible: %@", window];
        // Window settings are controlled by the interceptors
    }
}

/**
 * Initialize the WindowControlInjector
 */
+ (BOOL)initialize {
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"General"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Initializing WindowControlInjector"];

    // Load configuration from environment
    WCConfigurationManager *config = [WCConfigurationManager sharedManager];

    // Apply configured log level
    [[WCLogger sharedLogger] setLogLevel:config.logLevel];
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"General"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Log level set to %ld", (long)config.logLevel];

    // Get the interceptor registry
    WCInterceptorRegistry *registry = [WCInterceptorRegistry sharedRegistry];

    // Install all registered interceptors or just the enabled ones
    BOOL success;
    if (config.enabledInterceptors == UINT_MAX) {
        // All interceptors enabled
        success = [registry installAllInterceptors];
    } else {
        // Only specific interceptors
        success = [registry installInterceptorsWithOptions:config.enabledInterceptors];
    }

    // Apply configured window settings to any existing windows
    if (success) {
        [self processExistingWindows];
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"General"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"WindowControlInjector initialized %@", success ? @"successfully" : @"with errors"];

    return success;
}

/**
 * Find the path to the injector dylib
 */
+ (NSString *)findInjectorDylibPath {
    printf("[WindowControlInjector] Searching for injector dylib using path resolver...\n");

    // Use the path resolver to find the dylib
    NSString *dylibPath = [[WCPathResolver sharedResolver] resolvePathForDylib];

    if (dylibPath) {
        printf("[WindowControlInjector] Found dylib at: %s\n", [dylibPath UTF8String]);
        return dylibPath;
    }

    printf("[WindowControlInjector] ERROR: Could not find injector dylib\n");
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                 category:@"Injection"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Could not find injector dylib"];
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

    // Set log level using the enhanced logger
    [[WCLogger sharedLogger] setLogLevel:level];
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
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Launch"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"No property overrides specified, using default protection"];
        return [self protectApplication:applicationPath error:error];
    }

    printf("[WindowControlInjector] Protecting application with property overrides\n");
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Launch"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Applying protection to application with property overrides: %@", properties];

    // Create a custom configuration with the specified properties
    WCConfigurationManager *config = [WCConfigurationManager defaultConfiguration];

    // Apply properties from the dictionary to the configuration manager
    if (properties[@"windowLevel"]) {
        config.windowLevel = [properties[@"windowLevel"] integerValue];
    }

    if (properties[@"windowSharingType"]) {
        config.windowSharingType = [properties[@"windowSharingType"] integerValue];
    }

    if (properties[@"activationPolicy"]) {
        config.applicationActivationPolicy = [properties[@"activationPolicy"] integerValue];
    }

    if (properties[@"presentationOptions"]) {
        config.presentationOptions = [properties[@"presentationOptions"] unsignedIntegerValue];
    }

    if (properties[@"windowIgnoresMouseEvents"]) {
        config.windowIgnoresMouseEvents = [properties[@"windowIgnoresMouseEvents"] boolValue];
    }

    if (properties[@"windowCanBecomeKey"]) {
        config.windowCanBecomeKey = [properties[@"windowCanBecomeKey"] boolValue];
    }

    if (properties[@"windowCanBecomeMain"]) {
        config.windowCanBecomeMain = [properties[@"windowCanBecomeMain"] boolValue];
    }

    if (properties[@"windowHasShadow"]) {
        config.windowHasShadow = [properties[@"windowHasShadow"] boolValue];
    }

    if (properties[@"windowAlphaValue"]) {
        config.windowAlphaValue = [properties[@"windowAlphaValue"] doubleValue];
    }

    if (properties[@"windowStyleMask"]) {
        config.windowStyleMask = [properties[@"windowStyleMask"] unsignedIntegerValue];
    }

    if (properties[@"windowCollectionBehavior"]) {
        config.windowCollectionBehavior = [properties[@"windowCollectionBehavior"] unsignedIntegerValue];
    }

    if (properties[@"windowAcceptsMouseMovedEvents"]) {
        config.windowAcceptsMouseMovedEvents = [properties[@"windowAcceptsMouseMovedEvents"] boolValue];
    }

    if (properties[@"logLevel"]) {
        config.logLevel = [properties[@"logLevel"] integerValue];
    }

    if (properties[@"enabledInterceptors"]) {
        config.enabledInterceptors = [properties[@"enabledInterceptors"] unsignedIntegerValue];
    }

    if (properties[@"options"]) {
        config.options = [properties[@"options"] unsignedIntegerValue];
    }

    // Generate a temporary file path for the configuration
    NSString *configPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"wci_config_temp.json"];

    // Save the configuration to the temporary file
    if (![config saveToFile:configPath]) {
        printf("[WindowControlInjector] ERROR: Failed to save configuration to temporary file\n");
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:107
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to save configuration"}];
        }
        return NO;
    }

    // Set up environment to tell the injected dylib where to find the configuration
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"WCI_CONFIG_PATH"] = configPath;

    // Set DYLD_INSERT_LIBRARIES environment variable to inject dylib
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

    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;

    // Create application URL
    NSURL *appURL = [NSURL fileURLWithPath:applicationPath];

    // For macOS 11.0 and later, use the new API
    if (@available(macOS 11.0, *)) {
        // Create configuration with newer API
        NSWorkspaceOpenConfiguration *workspaceConfig = [NSWorkspaceOpenConfiguration configuration];
        [workspaceConfig setEnvironment:env];
        [workspaceConfig setCreatesNewApplicationInstance:YES];

        // Create a semaphore to wait for the completion handler
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block BOOL launchSuccess = NO;
        __block NSError *launchError = nil;

        [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                        configuration:workspaceConfig
                                    completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable appError) {
            if (app) {
                launchSuccess = YES;
            } else {
                launchError = appError;
                launchSuccess = NO;
            }
            dispatch_semaphore_signal(semaphore);
        }];

        // Wait for the launch to complete (with timeout)
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC);
        if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
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
        // For older macOS versions, use the deprecated API
        NSError *launchError = nil;
        NSRunningApplication *app = [[NSWorkspace sharedWorkspace]
                                     launchApplicationAtURL:appURL
                                     options:NSWorkspaceLaunchNewInstance
                                     configuration:@{NSWorkspaceLaunchConfigurationEnvironment: env}
                                     error:&launchError];

        if (app) {
            return YES;
        } else {
            if (error) {
                *error = launchError ? launchError : [NSError errorWithDomain:WCProtectorErrorDomain
                                                                         code:106
                                                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to launch application"}];
            }
            return NO;
        }
    }
}

@end

// C function wrappers for the public API
BOOL WCProtectApplication(NSString *applicationPath, NSError **error) {
    return [WCProtector protectApplication:applicationPath error:error];
}

BOOL WCProtectApplicationWithProperties(NSString *applicationPath, NSDictionary *properties, NSError **error) {
    return [WCProtector protectApplicationWithProperties:applicationPath withProperties:properties error:error];
}

BOOL WCInitialize(void) {
    return [WCProtector initialize];
}
