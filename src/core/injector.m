/**
 * @file injector.m
 * @brief Implementation of the injection mechanism for WindowControlInjector
 */

#import "../../include/injector.h"
#import "../../include/window_control.h"
#import "../util/logger.h"
#import "../util/error_manager.h"
#import "../util/path_resolver.h"
#import "../util/wc_cgs_functions.h"
#import "../util/wc_cgs_types.h"
#import "wc_injector_config.h"
#import "wc_window_bridge.h"
#import "wc_window_scanner.h"
#import "wc_window_protector.h"
#import "wc_window_info.h"
#import "../interceptors/interceptor_registry.h"
#import "../interceptors/nswindow_interceptor.h"
#import "../interceptors/nsapplication_interceptor.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

// Error codes - using error manager categories
NSInteger const WCErrorInvalidArguments = 100;
NSInteger const WCErrorApplicationNotFound = 101;
NSInteger const WCErrorInjectionFailed = 102;

// Use the error domain from WCError rather than redefining it
// This avoids duplicate symbol errors

// Static variables - removing gDylibPath as it's now handled by path resolver

@implementation WCInjector

#pragma mark - Injection Methods

/**
 * Inject the WindowControlInjector dylib into an application
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath error:(NSError **)error {
    return [self injectIntoApplication:applicationPath options:WCInjectionOptionAll error:error];
}

/**
 * Inject the WindowControlInjector dylib with specific options
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                      options:(WCInjectionOptions)options
                        error:(NSError **)error {
    WCInjectorConfig *config = [WCInjectorConfig defaultConfig];
    config.options = options;
    return [self injectIntoApplication:applicationPath config:config error:error];
}

/**
 * Inject the WindowControlInjector dylib with detailed configuration
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath
                       config:(WCInjectorConfig *)config
                        error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInvalidArguments
                                        message:@"Application path is required"];
        }
        return NO;
    }

    // Check if application exists
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:applicationPath isDirectory:&isDirectory] || !isDirectory) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorApplicationNotFound
                                        message:[NSString stringWithFormat:@"Application not found at path: %@", applicationPath]];
        }
        return NO;
    }

    // Get dylib path using the path resolver
    NSString *dylibPath = [[WCPathResolver sharedResolver] resolvePathForDylib];
    if (!dylibPath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInjectionFailed
                                        message:@"Could not find WindowControlInjector dylib"];
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

    [task setEnvironment:env];

    // Set arguments to open the application with -n flag to force a new instance
    [task setArguments:@[@"-n", @"-a", applicationPath]];

    // Launch the application
    @try {
        [task launch];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Injection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully injected dylib into application: %@", applicationPath];
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInjectionFailed
                                        message:[NSString stringWithFormat:@"Failed to launch application: %@", exception.reason]];
        }
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Injection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to inject dylib: %@", exception.reason];
        return NO;
    }
}

#pragma mark - Launch Application Methods

/**
 * Launch an application with arguments and injected dylib
 */
+ (NSTask *)launchApplication:(NSString *)applicationPath
                    arguments:(NSArray<NSString *> *)arguments
                        error:(NSError **)error {
    WCInjectorConfig *config = [WCInjectorConfig defaultConfig];
    return [self launchApplication:applicationPath arguments:arguments config:config error:error];
}

/**
 * Launch an application with custom configuration
 */
+ (NSTask *)launchApplication:(NSString *)applicationPath
                    arguments:(NSArray<NSString *> *)arguments
                       config:(WCInjectorConfig *)config
                        error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInvalidArguments
                                        message:@"Application path is required"];
        }
        return nil;
    }

    // Check if application exists
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:applicationPath isDirectory:&isDirectory] || !isDirectory) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorApplicationNotFound
                                        message:[NSString stringWithFormat:@"Application not found at path: %@", applicationPath]];
        }
        return nil;
    }

    // Get dylib path using the path resolver
    NSString *dylibPath = [[WCPathResolver sharedResolver] resolvePathForDylib];
    if (!dylibPath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInjectionFailed
                                        message:@"Could not find WindowControlInjector dylib"];
        }
        return nil;
    }

    // Find the executable within the application bundle using path resolver
    NSString *executablePath = [[WCPathResolver sharedResolver] resolveExecutablePathForApplication:applicationPath];

    if (!executablePath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorApplicationNotFound
                                        message:[NSString stringWithFormat:@"Could not find executable in application: %@", applicationPath]];
        }
        return nil;
    }

    // Convert config to environment variables
    NSMutableDictionary *injectionEnv = [NSMutableDictionary dictionary];
    [injectionEnv addEntriesFromDictionary:[config asDictionary]];

    // Prepare environment variables for injection
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    // Set DYLD_INSERT_LIBRARIES to inject the dylib
    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;

    // Add configuration environment variables
    [env addEntriesFromDictionary:injectionEnv];

    // Launch the application with the prepared environment
    return [self launchApplicationWithPath:executablePath arguments:arguments environment:env error:error];
}

/**
 * Launch an application with custom environment variables
 */
+ (NSTask *)launchApplicationWithPath:(NSString *)applicationPath
                            arguments:(NSArray<NSString *> *)arguments
                          environment:(NSDictionary<NSString *, NSString *> *)environment
                                error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInvalidArguments
                                        message:@"Application path is required"];
        }
        return nil;
    }

    // Check if file exists and is executable
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:applicationPath]) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorApplicationNotFound
                                        message:[NSString stringWithFormat:@"Executable not found or not executable at path: %@", applicationPath]];
        }
        return nil;
    }

    // Create task to launch application
    NSTask *task = [NSTask new];
    [task setLaunchPath:applicationPath];

    // Set the environment
    [task setEnvironment:environment];

    // Set arguments if provided
    if (arguments && arguments.count > 0) {
        [task setArguments:arguments];
    }

    // Launch the application
    @try {
        [task launch];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Injection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully launched application with injected dylib: %@", applicationPath];
        return task;
    } @catch (NSException *exception) {
        if (error) {
            *error = [WCError errorWithCategory:WCErrorCategoryInjection
                                           code:WCErrorInjectionFailed
                                        message:[NSString stringWithFormat:@"Failed to launch application: %@", exception.reason]];
        }
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Injection"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to launch application: %@", exception.reason];
        return nil;
    }
}

/**
 * Find the path to the WindowControlInjector dylib
 *
 * This method is now a wrapper around the path resolver for backward compatibility.
 */
+ (NSString *)findDylibPath {
    return [[WCPathResolver sharedResolver] resolvePathForDylib];
}

/**
 * Set a custom path for the WindowControlInjector dylib
 *
 * This method is now a wrapper around the path resolver for backward compatibility.
 */
+ (void)setDylibPath:(NSString *)path {
    [[WCPathResolver sharedResolver] setCustomDylibPath:path];
}

@end

/**
 * Initialize the WindowControlInjector
 *
 * This function is called when the dylib is loaded to initialize the
 * interceptors and set up window protection.
 */
BOOL WCInitialize(void) {
    // First, resolve any CGS functions we'll need
    BOOL cgsResolved = [[WCCGSFunctions sharedFunctions] resolveAllFunctions];

    if (!cgsResolved) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Initialization"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"CGS functions could not be fully resolved - some features may be limited"];
    }

    // Register interceptors
    BOOL success = [[WCInterceptorRegistry sharedRegistry] registerAllInterceptors];

    // Initialize the window bridge
    [WCWindowBridge setupWindowBridge];

    // Set up window protector defaults
    [WCWindowProtector setDebounceInterval:0.3]; // 300ms default

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Initialization"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"WindowControlInjector initialized %@", success ? @"successfully" : @"with errors"];

    return success;
}

/**
 * Static flag to ensure we only initialize once
 */
static BOOL gLibraryInitialized = NO;
static dispatch_once_t gInitializeOnceToken;

/**
 * Dylib initialization function that will be called when the library is loaded
 */
__attribute__((constructor))
static void initialize(void) {
    // Use dispatch_once to guarantee this only runs once
    dispatch_once(&gInitializeOnceToken, ^{
        // Protect against any re-initialization attempts
        if (gLibraryInitialized) {
            return;
        }

        // Direct filesystem logging to confirm dylib is being loaded using path resolver
        NSString *logPath = [[WCPathResolver sharedResolver] logFilePath];
        NSString *logMessage = [NSString stringWithFormat:@"[%@] WindowControlInjector dylib loaded\n",
                               [NSDate date]];

        // Use a @try/@catch block to prevent crashes during initialization
        @try {
            NSFileHandle *fileHandle;
            if ([[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
                fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
                [fileHandle seekToEndOfFile];
            } else {
                [[NSFileManager defaultManager] createFileAtPath:logPath contents:[NSData data] attributes:nil];
                fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
            }

            if (fileHandle) {
                [fileHandle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
                [fileHandle closeFile];
            }

            // Log initialization start
            NSFileHandle *initialFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
            [initialFileHandle seekToEndOfFile];
            [initialFileHandle writeData:[@"WindowControlInjector initialization started\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [initialFileHandle closeFile];

            // Wait a moment before initializing to let the app finish loading
            // This can help prevent crashes during app startup
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // Configure logger first
                [[WCLogger sharedLogger] setLogLevel:WCLogLevelInfo];

                // Call the initialization function - this will use the registry
                BOOL success = WCInitialize();

                // Detect application type and configure scanner accordingly
                if (success) {
                    // Get the application path
                    NSBundle *mainBundle = [NSBundle mainBundle];
                    NSString *bundlePath = [mainBundle bundlePath];

                    // Detect application type
                    WCApplicationType appType = [WCWindowBridge detectApplicationTypeForPath:bundlePath];

                    // Configure scanner for this application type
                    [[WCWindowScanner sharedScanner] configureForApplicationType:appType];

                    // Start the scanner with the appropriate interval
                    [[WCWindowScanner sharedScanner] startScanningWithInterval:
                        [[WCWindowScanner sharedScanner] currentScanInterval]];
                }

                // Mark as initialized
                gLibraryInitialized = YES;

                // Log result
                NSFileHandle *finalFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
                [finalFileHandle seekToEndOfFile];
                NSString *resultMessage = success ?
                    @"WindowControlInjector initialized successfully\n" :
                    @"WindowControlInjector initialization failed\n";
                [finalFileHandle writeData:[resultMessage dataUsingEncoding:NSUTF8StringEncoding]];
                [finalFileHandle closeFile];

                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"WindowControlInjector initialized successfully: %@", success ? @"YES" : @"NO"];
            });
        } @catch (NSException *exception) {
            // Log the exception but don't crash
            NSFileHandle *errorHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
            [errorHandle seekToEndOfFile];
            NSString *errorMessage = [NSString stringWithFormat:@"WindowControlInjector initialization error: %@\n", exception];
            [errorHandle writeData:[errorMessage dataUsingEncoding:NSUTF8StringEncoding]];
            [errorHandle closeFile];
        }
    });
}

/**
 * C function wrappers for backward compatibility
 */
BOOL WCInjectIntoApplication(NSString *applicationPath, NSError **error) {
    return [WCInjector injectIntoApplication:applicationPath error:error];
}

/**
 * Inject with options C function wrapper
 */
BOOL WCInjectIntoApplicationWithOptions(NSString *applicationPath, WCInjectionOptions options, NSError **error) {
    return [WCInjector injectIntoApplication:applicationPath options:options error:error];
}

/**
 * Get the version string
 */
NSString *WCGetVersion(void) {
    return @"1.0.0";
}

/**
 * Get the build date string
 */
NSString *WCGetBuildDate(void) {
#ifdef BUILD_DATE
    return [NSString stringWithUTF8String:BUILD_DATE];
#else
    return @"Development Build";
#endif
}
