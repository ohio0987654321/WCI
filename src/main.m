/**
 * @file main.m
 * @brief Command-line interface for WindowControlInjector
 */

#import <Foundation/Foundation.h>
#import "../include/window_control.h"
#import "../include/injector.h"
#import "../include/profiles.h"
#import "../src/util/logger.h"

// Function prototypes
void printUsage(void);
void printVersion(void);
BOOL parsePropertyOverride(NSString *propertyString, NSMutableDictionary *overrides);
NSString *resolveApplicationPath(NSString *path);

/**
 * Main entry point for the WindowControlInjector command-line tool
 */
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Default log level
        WCSetLogLevel(WCLogLevelWarning);

        // Parse command line arguments
        NSMutableArray<NSString *> *profileNames = [NSMutableArray array];
        NSMutableDictionary *propertyOverrides = [NSMutableDictionary dictionary];
        NSString *applicationPath = nil;
        BOOL applyAll = NO;

        // Skip the program name (argv[0])
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];

            // Handle options
            if ([arg hasPrefix:@"-"]) {
                if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
                    printUsage();
                    return 0;
                } else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"--verbose"]) {
                    WCSetLogLevel(WCLogLevelDebug);
                } else if ([arg isEqualToString:@"--version"]) {
                    printVersion();
                    return 0;
                } else if ([arg isEqualToString:@"--invisible"]) {
                    [profileNames addObject:@"invisible"];
                } else if ([arg isEqualToString:@"--stealth"]) {
                    [profileNames addObject:@"stealth"];
                } else if ([arg isEqualToString:@"--unfocusable"]) {
                    [profileNames addObject:@"unfocusable"];
                } else if ([arg isEqualToString:@"--click-through"]) {
                    [profileNames addObject:@"click-through"];
                } else if ([arg isEqualToString:@"--all"]) {
                    applyAll = YES;
                } else if ([arg hasPrefix:@"--property"]) {
                    // Handle property override
                    if (i + 1 < argc) {
                        NSString *propertyString = [NSString stringWithUTF8String:argv[++i]];
                        if (!parsePropertyOverride(propertyString, propertyOverrides)) {
                            WCLogError(@"Invalid property override format: %@", propertyString);
                            WCLogError(@"Expected format: CLASS.PROPERTY=VALUE");
                            return 1;
                        }
                    } else {
                        WCLogError(@"--property option requires a value");
                        return 1;
                    }
                } else {
                    WCLogError(@"Unknown option: %@", arg);
                    printUsage();
                    return 1;
                }
            } else {
                // Non-option argument is the application path
                if (applicationPath == nil) {
                    applicationPath = arg;
                } else {
                    WCLogError(@"Multiple application paths specified");
                    printUsage();
                    return 1;
                }
            }
        }

        // Validate arguments
        if (applicationPath == nil) {
            WCLogError(@"No application path specified");
            printUsage();
            return 1;
        }

        // Resolve application path
        NSString *resolvedPath = resolveApplicationPath(applicationPath);
        if (resolvedPath == nil) {
            WCLogError(@"Invalid application path: %@", applicationPath);
            return 1;
        }

        // If --all is specified, add all profiles
        if (applyAll) {
            [profileNames removeAllObjects]; // Clear any individually specified profiles
            [profileNames addObjectsFromArray:@[@"invisible", @"stealth", @"unfocusable", @"click-through"]];
        }

        NSError *error = nil;
        BOOL success = NO;

        // Initialize the WindowControlInjector
        if (!WCInitialize()) {
            WCLogError(@"Failed to initialize WindowControlInjector");
            return 1;
        }

        // Apply profiles or property overrides
        if (profileNames.count > 0) {
            // Apply profiles
            WCLogInfo(@"Applying profiles: %@", [profileNames componentsJoinedByString:@", "]);
            success = [WCInjector injectIntoApplication:resolvedPath
                                          withProfiles:profileNames
                                                 error:&error];
        } else if (propertyOverrides.count > 0) {
            // Apply property overrides
            WCLogInfo(@"Applying property overrides: %@", propertyOverrides);
            success = [WCInjector injectIntoApplication:resolvedPath
                                 withPropertyOverrides:propertyOverrides
                                                 error:&error];
        } else {
            WCLogError(@"No profiles or property overrides specified");
            printUsage();
            return 1;
        }

        if (!success) {
            if (error) {
                WCLogError(@"Injection failed: %@", [error localizedDescription]);
            } else {
                WCLogError(@"Injection failed for unknown reason");
            }
            return 1;
        }

        WCLogInfo(@"Successfully injected into application: %@", resolvedPath);
        return 0;
    }
}

/**
 * Print the usage information
 */
void printUsage(void) {
    printf("Usage: injector [options] <application-path>\n\n");
    printf("Options:\n");
    printf("  --invisible        Make windows invisible to screen recording\n");
    printf("  --stealth          Hide application from Dock and status bar\n");
    printf("  --unfocusable      Prevent windows from receiving focus\n");
    printf("  --click-through    Make windows click-through (ignore mouse events)\n");
    printf("  --all              Apply all profiles\n\n");

    printf("  --property CLASS.PROPERTY=VALUE   Override specific property\n\n");

    printf("  -v, --verbose      Enable verbose logging\n");
    printf("  -h, --help         Show this help message\n");
    printf("  --version          Show version information\n\n");

    printf("Examples:\n");
    printf("  injector --invisible /Applications/TextEdit.app\n");
    printf("  injector --stealth --unfocusable /Applications/Calculator.app\n");
    printf("  injector --all /Applications/Notes.app\n");
    printf("  injector --property NSWindow.backgroundColor=0,0,0,0.5 /Applications/Safari.app\n");
}

/**
 * Print the version information
 */
void printVersion(void) {
    printf("WindowControlInjector version 1.0.0\n");
    printf("Copyright (c) 2025. All rights reserved.\n");
}

/**
 * Parse a property override string in the format CLASS.PROPERTY=VALUE
 *
 * @param propertyString The property override string
 * @param overrides The dictionary to add the parsed override to
 * @return YES if the property string was parsed successfully, NO otherwise
 */
BOOL parsePropertyOverride(NSString *propertyString, NSMutableDictionary *overrides) {
    // Split by the first equals sign
    NSRange equalsRange = [propertyString rangeOfString:@"="];
    if (equalsRange.location == NSNotFound) {
        return NO;
    }

    NSString *propertyPath = [propertyString substringToIndex:equalsRange.location];
    NSString *valueString = [propertyString substringFromIndex:equalsRange.location + 1];

    // Split the property path by the first dot
    NSRange dotRange = [propertyPath rangeOfString:@"."];
    if (dotRange.location == NSNotFound) {
        return NO;
    }

    NSString *className = [propertyPath substringToIndex:dotRange.location];
    NSString *propertyName = [propertyPath substringFromIndex:dotRange.location + 1];

    // Parse the value (basic types only for now)
    id value = nil;

    // Try to parse as a number
    if ([valueString isEqualToString:@"YES"] || [valueString isEqualToString:@"true"]) {
        value = @YES;
    } else if ([valueString isEqualToString:@"NO"] || [valueString isEqualToString:@"false"]) {
        value = @NO;
    } else if ([valueString rangeOfString:@","].location != NSNotFound) {
        // Parse as color (r,g,b,a)
        NSArray<NSString *> *components = [valueString componentsSeparatedByString:@","];
        if (components.count == 3 || components.count == 4) {
            CGFloat r = [components[0] floatValue];
            CGFloat g = [components[1] floatValue];
            CGFloat b = [components[2] floatValue];
            CGFloat a = (components.count == 4) ? [components[3] floatValue] : 1.0;

            // Create a string representation of the color with limited decimal places
            value = [NSString stringWithFormat:@"%.2f,%.2f,%.2f,%.2f", r, g, b, a];
        } else {
            return NO;
        }
    } else {
        // Try to parse as a number
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *number = [formatter numberFromString:valueString];

        if (number != nil) {
            value = number;
        } else {
            // Treat as a string
            value = valueString;
        }
    }

    // Add to overrides
    if (overrides[className] == nil) {
        overrides[className] = [NSMutableDictionary dictionary];
    }

    ((NSMutableDictionary *)overrides[className])[propertyName] = value;

    return YES;
}

/**
 * Resolve and validate the application path
 *
 * @param path The application path to resolve
 * @return The resolved path, or nil if the path is invalid
 */
NSString *resolveApplicationPath(NSString *path) {
    // Check if the path is valid
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];

    if (!exists) {
        WCLogError(@"Application not found at path: %@", path);
        return nil;
    }

    // If it's a directory, check if it's an app bundle
    if (isDirectory) {
        // Check if it has the .app extension
        if (![path.pathExtension isEqualToString:@"app"]) {
            WCLogWarning(@"Path doesn't have .app extension: %@", path);
        }

        // Check for Info.plist
        NSString *infoPlistPath = [path stringByAppendingPathComponent:@"Contents/Info.plist"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:infoPlistPath]) {
            WCLogError(@"Not a valid application bundle (missing Info.plist): %@", path);
            return nil;
        }

        // Get the executable path from Info.plist
        NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
        NSString *executableName = infoPlist[@"CFBundleExecutable"];

        if (executableName == nil) {
            WCLogError(@"Invalid Info.plist (missing CFBundleExecutable): %@", infoPlistPath);
            return nil;
        }

        NSString *executablePath = [path stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"Contents/MacOS/%@", executableName]];

        if (![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) {
            WCLogError(@"Executable not found: %@", executablePath);
            return nil;
        }

        return executablePath;
    } else {
        // It's a file, check if it's executable
        if (![[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
            WCLogError(@"File is not executable: %@", path);
            return nil;
        }

        return path;
    }
}
