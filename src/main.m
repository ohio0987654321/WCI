/**
 * @file main.m
 * @brief Command-line interface for WindowControlInjector
 */

#import <Foundation/Foundation.h>
#import "../src/core/protector.h"
#import "../src/util/logger.h"

// Function prototypes
void printUsage(void);
void printVersion(void);
NSString *resolveApplicationPath(NSString *path, BOOL debugMode);

/**
 * Main entry point for the WindowControlInjector command-line tool
 */
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Default log level
        [WCProtector setLogLevel:WCLogLevelWarning];

        NSString *applicationPath = nil;
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
                    [WCProtector setLogLevel:WCLogLevelDebug];
                } else if ([arg isEqualToString:@"--version"]) {
                    printVersion();
                    return 0;
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

        WCLogInfo(@"Using application: %@", applicationPath);

        // Initialize the WindowControlInjector
        if (!WCInitialize()) {
            WCLogError(@"Failed to initialize WindowControlInjector");
            return 1;
        }

        // Apply protection
        NSError *error = nil;
        BOOL success = WCProtectApplication(applicationPath, &error);

        if (!success) {
            if (error) {
                WCLogError(@"Protection failed: %@", [error localizedDescription]);
            } else {
                WCLogError(@"Protection failed for unknown reason");
            }
            return 1;
        }

        WCLogInfo(@"Successfully protected application: %@", applicationPath);
        return 0;
    }
}

/**
 * Print the usage information
 */
void printUsage(void) {
    printf("Usage: injector [options] <application-path>\n\n");
    printf("Options:\n");
    printf("  -v, --verbose      Enable verbose logging\n");
    printf("  -h, --help         Show this help message\n");
    printf("  --version          Show version information\n\n");

    printf("Examples:\n");
    printf("  ./build/injector /Applications/TextEdit.app\n");
    printf("  ./build/injector -v /Applications/Calculator.app   # With verbose logging\n");
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
