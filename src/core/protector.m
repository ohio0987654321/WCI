/**
 * @file protector.m
 * @brief Implementation of core protection functionality for WindowControlInjector
 */

#import "protector.h"
#import "../util/logger.h"
#import "../interceptors/nswindow_interceptor.h"
#import "../interceptors/nsapplication_interceptor.h"
#import "direct_window_control.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

// Error domain
NSString *const WCProtectorErrorDomain = @"com.windowcontrolinjector.protector";

@implementation WCProtector

/**
 * Apply all protection features to the specified application
 */
+ (BOOL)protectApplication:(NSString *)applicationPath error:(NSError **)error {
    if (!applicationPath) {
        if (error) {
            *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                         code:100
                                     userInfo:@{NSLocalizedDescriptionKey: @"Application path is nil"}];
        }
        return NO;
    }

    WCLogInfo(@"Applying protection to application: %@", applicationPath);

    @try {
        // Set environment variable for dylib injection
        NSString *dylibPath = [self findInjectorDylibPath];
        if (!dylibPath) {
            if (error) {
                *error = [NSError errorWithDomain:WCProtectorErrorDomain
                                             code:101
                                         userInfo:@{NSLocalizedDescriptionKey: @"Couldn't find injector dylib"}];
            }
            return NO;
        }

        WCLogInfo(@"Using dylib: %@", dylibPath);

        // Set environment variable DYLD_INSERT_LIBRARIES
        setenv("DYLD_INSERT_LIBRARIES", [dylibPath UTF8String], 1);

    // Check if this is an app bundle
    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:applicationPath isDirectory:&isDirectory];

    NSTask *task = [[NSTask alloc] init];

    if (isDirectory && [applicationPath hasSuffix:@".app"]) {
        // Use the 'open' command to launch app bundles
        WCLogInfo(@"Detected .app bundle, using /usr/bin/open");
        [task setLaunchPath:@"/usr/bin/open"];
        [task setArguments:@[@"-a", applicationPath]];
    } else {
        // Try to directly execute the file
        WCLogInfo(@"Using direct execution for: %@", applicationPath);
        [task setLaunchPath:applicationPath];
    }

    // Set environment variable for the child process
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"DYLD_INSERT_LIBRARIES"] = dylibPath;
    [task setEnvironment:env];

    // Inherit standard streams
    [task setStandardInput:[NSFileHandle fileHandleWithStandardInput]];
    [task setStandardOutput:[NSFileHandle fileHandleWithStandardOutput]];
    [task setStandardError:[NSFileHandle fileHandleWithStandardError]];

    // Launch application
    WCLogInfo(@"Launching application...");
    [task launch];

        WCLogInfo(@"Application launched successfully with protection");

        return YES;
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
 * Initialize the WindowControlInjector
 */
+ (BOOL)initialize {
    WCLogInfo(@"Initializing WindowControlInjector");

    // Install interceptors
    BOOL success = [WCNSWindowInterceptor install];
    success &= [WCNSApplicationInterceptor install];

    // Initialize direct window control if we're running inside an injected application
    // This won't do anything when running as the injector
    [WCDirectWindowControl applySettingsToAllWindows];

    WCLogInfo(@"WindowControlInjector initialized %@", success ? @"successfully" : @"with errors");

    return success;
}

/**
 * Find the path to the injector dylib
 */
+ (NSString *)findInjectorDylibPath {
    // Try to find the dylib relative to the executable
    NSString *executablePath = [[NSProcessInfo processInfo] arguments][0];
    NSString *executableDir = [executablePath stringByDeletingLastPathComponent];

    // Check common locations relative to executable
    NSArray *possiblePaths = @[
        [executableDir stringByAppendingPathComponent:@"libwindowcontrolinjector.dylib"],
        [executableDir stringByAppendingPathComponent:@"../lib/libwindowcontrolinjector.dylib"],
        @"/usr/local/lib/libwindowcontrolinjector.dylib"
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSString *path in possiblePaths) {
        if ([fileManager fileExistsAtPath:path]) {
            return path;
        }
    }

    // If we can't find it in common locations, try to get the path from the loaded dylibs
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        NSString *imagePath = [NSString stringWithUTF8String:path];
        if ([imagePath containsString:@"windowcontrolinjector"]) {
            return imagePath;
        }
    }

    // If we're already running as the dylib, get our own path using a known function in this file
    Dl_info info;
    if (dladdr((const void *)WCProtectApplication, &info)) {
        NSString *path = [NSString stringWithUTF8String:info.dli_fname];
        if ([path containsString:@"windowcontrolinjector"]) {
            return path;
        }
    }

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

@end

// C function wrappers for the public API
BOOL WCProtectApplication(NSString *applicationPath, NSError **error) {
    return [WCProtector protectApplication:applicationPath error:error];
}

BOOL WCInitialize(void) {
    return [WCProtector initialize];
}
