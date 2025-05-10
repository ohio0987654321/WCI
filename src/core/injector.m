/**
 * @file injector.m
 * @brief Implementation of the injection mechanism for WindowControlInjector
 */

#import "../../include/injector.h"
#import "../../include/window_control.h"
#import "../util/logger.h"
#import "../interceptors/nswindow_interceptor.h"
#import "../interceptors/nsapplication_interceptor.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

// Error codes
NSInteger const WCErrorInvalidArguments = 100;
NSInteger const WCErrorApplicationNotFound = 101;
NSInteger const WCErrorInjectionFailed = 102;

// Static variables
static NSString *gDylibPath = nil;

@implementation WCInjector

/**
 * Inject the WindowControlInjector dylib into an application
 */
+ (BOOL)injectIntoApplication:(NSString *)applicationPath error:(NSError **)error {
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

    [task setEnvironment:env];

    // Set arguments to open the application with -n flag to force a new instance
    [task setArguments:@[@"-n", @"-a", applicationPath]];

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

/**
 * Launch an application with arguments and injected dylib
 */
+ (NSTask *)launchApplication:(NSString *)applicationPath
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

/**
 * Find the path to the WindowControlInjector dylib
 */
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
        NSString *dylibPath = [location stringByAppendingPathComponent:@"libwindowcontrolinjector.dylib"];
        if ([fileManager fileExistsAtPath:dylibPath]) {
            return dylibPath;
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

    // If we're already running as the dylib, get our own path
    Dl_info info;
    if (dladdr((const void *)WCProtectApplication, &info)) {
        NSString *path = [NSString stringWithUTF8String:info.dli_fname];
        if ([path containsString:@"windowcontrolinjector"]) {
            return path;
        }
    }

    // Dylib not found
    WCLogError(@"Failed to find WindowControlInjector dylib");
    return nil;
}

/**
 * Set a custom path for the WindowControlInjector dylib
 */
+ (void)setDylibPath:(NSString *)path {
    gDylibPath = [path copy];
}

@end

/**
 * Dylib initialization function that will be called when the library is loaded
 */
__attribute__((constructor))
static void initialize(void) {
    // Direct filesystem logging to confirm dylib is being loaded
    NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"wci_debug.log"];
    NSString *logMessage = [NSString stringWithFormat:@"[%@] WindowControlInjector dylib loaded\n",
                           [NSDate date]];

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

    // Log initialization completion
    NSFileHandle *finalFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [finalFileHandle seekToEndOfFile];
    [finalFileHandle writeData:[@"WindowControlInjector initialization started\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [finalFileHandle closeFile];

    // Call the initialization function
    BOOL success = WCInitialize();

    // Log result
    finalFileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [finalFileHandle seekToEndOfFile];
    NSString *resultMessage = success ?
        @"WindowControlInjector initialized successfully\n" :
        @"WindowControlInjector initialization failed\n";
    [finalFileHandle writeData:[resultMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [finalFileHandle closeFile];
}

/**
 * C function wrappers for backward compatibility
 */
BOOL WCInjectIntoApplication(NSString *applicationPath, NSError **error) {
    return [WCInjector injectIntoApplication:applicationPath error:error];
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
