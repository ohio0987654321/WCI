/**
 * @file main.m
 * @brief Command-line interface for WindowControlInjector
 */

#import <Foundation/Foundation.h>
#import "../include/window_control.h"
#import "../include/injector.h"
#import "../include/profiles.h"
#import "../src/util/logger.h"
#import "../profiles/direct_control.h"
#import "../profiles/core.h"

// Function prototypes
void printUsage(void);
void printVersion(void);
void logDirectoryStructure(NSString *path, int maxDepth);
NSString* _logDirectoryStructureWithIndent(NSString *path, NSString *indent, int currentDepth, int maxDepth);
NSString *resolveApplicationPath(NSString *path, BOOL debugMode);

/**
 * Main entry point for the WindowControlInjector command-line tool
 */
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Default log level
        WCSetLogLevel(WCLogLevelWarning);

        // Parse command line arguments
        NSMutableArray<NSString *> *profileNames = [NSMutableArray array];
        NSString *applicationPath = nil;
        BOOL applyAll = NO;
        BOOL debugMode = NO;

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
                } else if ([arg isEqualToString:@"--debug"]) {
                    WCSetLogLevel(WCLogLevelDebug);
                    debugMode = YES;
                } else if ([arg isEqualToString:@"--version"]) {
                    printVersion();
                    return 0;
                } else if ([arg isEqualToString:@"--invisible"]) {
                    [profileNames addObject:@"invisible"];
                } else if ([arg isEqualToString:@"--stealth"]) {
                    [profileNames addObject:@"stealth"];
                // Removed unfocusable and click-through options
                } else if ([arg isEqualToString:@"--direct-control"]) {
                    [profileNames addObject:@"direct-control"];
                } else if ([arg isEqualToString:@"--core"]) {
                    [profileNames addObject:@"core"];
                } else if ([arg isEqualToString:@"--all"]) {
                    applyAll = YES;
                } else if ([arg isEqualToString:@"--enable-interaction"]) {
                    // Enable window interaction - allows windows to receive focus
                    WCLogInfo(@"Enabling window interaction");
                    [WCDirectControlProfile enableWindowInteraction];
                } else if ([arg isEqualToString:@"--disable-interaction"]) {
                    // Disable window interaction - prevents windows from receiving focus
                    WCLogInfo(@"Disabling window interaction");
                    [WCDirectControlProfile disableWindowInteraction];
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

        // Verify application path exists and executable can be found
        NSString *executablePath = resolveApplicationPath(applicationPath, debugMode);
        if (executablePath == nil) {
            WCLogError(@"Invalid application path: %@", applicationPath);
            return 1;
        }

        if (debugMode) {
            WCLogInfo(@"Found executable: %@", executablePath);
            WCLogInfo(@"Will use application bundle: %@", applicationPath);
        }

        // If --all is specified, add all default profiles
        if (applyAll) {
            [profileNames removeAllObjects]; // Clear any individually specified profiles
            [profileNames addObjectsFromArray:@[@"invisible", @"stealth"]];
        }
        // If no profiles specified, use core profile
        else if (profileNames.count == 0) {
            [profileNames removeAllObjects];
            [profileNames addObject:@"core"];

            WCLogInfo(@"Using default profile (core) with essential functionality");
        }

        NSError *error = nil;
        BOOL success = NO;

        // Initialize the WindowControlInjector
        if (!WCInitialize()) {
            WCLogError(@"Failed to initialize WindowControlInjector");
            return 1;
        }

        // Apply profiles
        WCLogInfo(@"Applying profiles: %@", [profileNames componentsJoinedByString:@", "]);
        success = [WCInjector injectIntoApplication:applicationPath
                                      withProfiles:profileNames
                                             error:&error];

        if (!success) {
            if (error) {
                WCLogError(@"Injection failed: %@", [error localizedDescription]);
            } else {
                WCLogError(@"Injection failed for unknown reason");
            }
            return 1;
        }

        WCLogInfo(@"Successfully injected into application: %@", applicationPath);
        return 0;
    }
}

/**
 * Print the usage information
 */
void printUsage(void) {
    printf("Usage: injector [options] <application-path>\n\n");
    printf("Options:\n");
    printf("  --core             Core functionality (screen recording protection, dock/status bar hiding) [DEFAULT]\n");
    printf("  --invisible        Make windows invisible to screen recording\n");
    printf("  --stealth          Hide application from Dock and status bar\n");
    // Removed unfocusable and click-through options from help text
    printf("  --direct-control   Enhanced control using direct Objective-C messaging\n");
    printf("  --all              Apply all profiles\n\n");

    printf("Window interaction control:\n");
    printf("  --enable-interaction  Allow windows to receive keyboard focus (while maintaining protection)\n");
    printf("  --disable-interaction Prevent windows from receiving keyboard focus\n\n");

    printf("  -v, --verbose      Enable verbose logging\n");
    printf("  --debug            Enable detailed path resolution debugging\n");
    printf("  -h, --help         Show this help message\n");
    printf("  --version          Show version information\n\n");

    printf("Examples:\n");
    printf("  ./build/injector /Applications/TextEdit.app               # Uses core profile (default)\n");
    printf("  ./build/injector --invisible /Applications/TextEdit.app   # Apply only invisibility\n");
    printf("  ./build/injector --stealth /Applications/Calculator.app\n");
    printf("  ./build/injector --direct-control --enable-interaction /Applications/Safari.app  # Advanced protection\n");
    printf("  ./build/injector --core /Applications/Terminal.app        # Explicit core profile\n");
}

/**
 * Print the version information
 */
void printVersion(void) {
    printf("WindowControlInjector version 1.0.0\n");
    printf("Copyright (c) 2025. All rights reserved.\n");
}


/**
 * Resolve and validate the application path
 *
 * @param path The application path to resolve
 * @param debugMode Whether to enable detailed debug output
 * @return The resolved path, or nil if the path is invalid
 */
NSString *resolveApplicationPath(NSString *path, BOOL debugMode) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *attemptedPaths = [NSMutableArray array];

    // 1. Normalize the path
    NSString *normalizedPath = [path stringByStandardizingPath];
    if (debugMode) {
        WCLogInfo(@"Resolving application path: %@", path);
        WCLogInfo(@"Normalized path: %@", normalizedPath);
    }

    // Check if the path is valid
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:normalizedPath isDirectory:&isDirectory];

    if (!exists) {
        if (debugMode) {
            WCLogDebug(@"Path does not exist: %@", normalizedPath);
        }
        WCLogError(@"Application not found at path: %@", path);
        return nil;
    }

    // 2. Handle symlinks
    NSString *resolvedPath = normalizedPath;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:normalizedPath error:nil];
    if (fileAttributes && fileAttributes[NSFileType] == NSFileTypeSymbolicLink) {
        NSError *linkError = nil;
        resolvedPath = [fileManager destinationOfSymbolicLinkAtPath:normalizedPath error:&linkError];

        if (linkError || !resolvedPath) {
            WCLogError(@"Failed to resolve symlink: %@", normalizedPath);
            if (linkError) {
                WCLogError(@"Error: %@", [linkError localizedDescription]);
            }
            return nil;
        }

        if (debugMode) {
            WCLogInfo(@"Resolved symlink to: %@", resolvedPath);
        }

        // Check if the resolved path exists
        exists = [fileManager fileExistsAtPath:resolvedPath isDirectory:&isDirectory];
        if (!exists) {
            WCLogError(@"Symlink destination does not exist: %@", resolvedPath);
            return nil;
        }
    }

    // 3. If it's a directory, try to handle it as an app bundle or find an executable
    if (isDirectory) {
        if (debugMode) {
            WCLogInfo(@"Path is a directory: %@", resolvedPath);
        }

        // 3.1 Check if it has the .app extension (common but not required)
        BOOL isAppBundle = [resolvedPath.pathExtension isEqualToString:@"app"];
        if (!isAppBundle) {
            WCLogWarning(@"Path doesn't have .app extension: %@", resolvedPath);
        }

        // 3.2 Try standard app bundle structure
        NSString *contentsPath = [resolvedPath stringByAppendingPathComponent:@"Contents"];
        NSString *macOSPath = [contentsPath stringByAppendingPathComponent:@"MacOS"];
        NSString *infoPlistPath = [contentsPath stringByAppendingPathComponent:@"Info.plist"];

        // 3.3 Try to get executable from Info.plist if it exists
        if ([fileManager fileExistsAtPath:infoPlistPath]) {
            if (debugMode) {
                WCLogInfo(@"Found Info.plist at: %@", infoPlistPath);
            }

            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
            NSString *executableName = infoPlist[@"CFBundleExecutable"];

            if (executableName) {
                if (debugMode) {
                    WCLogInfo(@"Found CFBundleExecutable in Info.plist: %@", executableName);
                }

                // Standard location
                NSString *executablePath = [macOSPath stringByAppendingPathComponent:executableName];
                [attemptedPaths addObject:executablePath];

                if ([fileManager fileExistsAtPath:executablePath] &&
                    [fileManager isExecutableFileAtPath:executablePath]) {
                    if (debugMode) {
                        WCLogInfo(@"Found executable at standard location: %@", executablePath);
                    }
                    return executablePath;
                }

                // Try alternative locations if standard failed

                // Try without MacOS dir
                executablePath = [contentsPath stringByAppendingPathComponent:executableName];
                [attemptedPaths addObject:executablePath];
                if ([fileManager fileExistsAtPath:executablePath] &&
                    [fileManager isExecutableFileAtPath:executablePath]) {
                    if (debugMode) {
                        WCLogInfo(@"Found executable directly in Contents: %@", executablePath);
                    }
                    return executablePath;
                }

                // Try at app bundle root
                executablePath = [resolvedPath stringByAppendingPathComponent:executableName];
                [attemptedPaths addObject:executablePath];
                if ([fileManager fileExistsAtPath:executablePath] &&
                    [fileManager isExecutableFileAtPath:executablePath]) {
                    if (debugMode) {
                        WCLogInfo(@"Found executable at app bundle root: %@", executablePath);
                    }
                    return executablePath;
                }
            } else {
                if (debugMode) {
                    WCLogDebug(@"No CFBundleExecutable found in Info.plist");
                }
            }
        }

        // 3.4 Try fallback: use app name as executable name
        if ([fileManager fileExistsAtPath:macOSPath]) {
            NSString *appName = [[resolvedPath lastPathComponent] stringByDeletingPathExtension];
            NSString *executablePath = [macOSPath stringByAppendingPathComponent:appName];
            [attemptedPaths addObject:executablePath];

            if ([fileManager fileExistsAtPath:executablePath] &&
                [fileManager isExecutableFileAtPath:executablePath]) {
                if (debugMode) {
                    WCLogInfo(@"Found executable using app name: %@", executablePath);
                }
                return executablePath;
            }
        }

        // 3.5 Last resort: try to find any executable in MacOS directory
        if ([fileManager fileExistsAtPath:macOSPath]) {
            NSError *error = nil;
            NSArray *macOSContents = [fileManager contentsOfDirectoryAtPath:macOSPath error:&error];

            if (error == nil && macOSContents.count > 0) {
                if (debugMode) {
                    WCLogInfo(@"Searching for any executable in MacOS directory");
                }

                for (NSString *item in macOSContents) {
                    NSString *itemPath = [macOSPath stringByAppendingPathComponent:item];
                    [attemptedPaths addObject:itemPath];

                    if ([fileManager isExecutableFileAtPath:itemPath]) {
                        if (debugMode) {
                            WCLogInfo(@"Found executable in MacOS directory: %@", itemPath);
                        }
                        return itemPath;
                    }
                }
            }
        }

        // 3.6 Check if the directory itself is executable (rare)
        if ([fileManager isExecutableFileAtPath:resolvedPath]) {
            if (debugMode) {
                WCLogInfo(@"Directory itself is executable: %@", resolvedPath);
            }
            return resolvedPath;
        }

        // 3.7 Nothing worked, provide detailed error
        WCLogError(@"Could not find executable in application bundle: %@", resolvedPath);
        if (debugMode) {
            WCLogDebug(@"Attempted paths:");
            for (NSString *attempt in attemptedPaths) {
                WCLogDebug(@"  - %@", attempt);
            }

            // Try to show directory structure for debugging
            WCLogDebug(@"Directory structure:");
            logDirectoryStructure(resolvedPath, 2); // Limit depth to avoid huge output
        }

        return nil;
    } else {
        // 4. It's a file, check if it's executable
        if (debugMode) {
            WCLogInfo(@"Path is a file: %@", resolvedPath);
        }

        if ([fileManager isExecutableFileAtPath:resolvedPath]) {
            if (debugMode) {
                WCLogInfo(@"File is executable: %@", resolvedPath);
            }
            return resolvedPath;
        } else {
            WCLogError(@"File is not executable: %@", resolvedPath);
            return nil;
        }
    }
}

/**
 * Helper method to log directory structure for debugging
 */
void logDirectoryStructure(NSString *path, int maxDepth) {
    _logDirectoryStructureWithIndent(path, @"  ", 0, maxDepth);
}

/**
 * Recursive helper for logging directory structure
 */
NSString* _logDirectoryStructureWithIndent(NSString *path, NSString *indent, int currentDepth, int maxDepth) {
    if (currentDepth > maxDepth) {
        return @"";
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:&error];

    if (error) {
        WCLogDebug(@"%@%@ (Error reading contents: %@)", indent, [path lastPathComponent], [error localizedDescription]);
        return @"";
    }

    // Log this directory
    WCLogDebug(@"%@%@/", indent, [path lastPathComponent]);

    // Prepare next level indent
    NSString *nextIndent = [indent stringByAppendingString:@"  "];

    for (NSString *item in contents) {
        NSString *itemPath = [path stringByAppendingPathComponent:item];
        BOOL isDirectory = NO;

        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                _logDirectoryStructureWithIndent(itemPath, nextIndent, currentDepth + 1, maxDepth);
            } else {
                BOOL isExecutable = [fileManager isExecutableFileAtPath:itemPath];
                if (isExecutable) {
                    WCLogDebug(@"%@%@ (executable)", nextIndent, item);
                } else {
                    WCLogDebug(@"%@%@", nextIndent, item);
                }
            }
        }
    }

    return @"";
}
