/**
 * @file main.m
 * @brief Command-line interface for WindowControlInjector
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../src/core/protector.h"
#import "../src/util/logger.h"

// Function prototypes
void printUsage(void);
NSString *resolveApplicationPath(NSString *path, BOOL debugMode);

/**
 * Main entry point for the WindowControlInjector command-line tool
 */
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Default log level
        [WCProtector setLogLevel:WCLogLevelWarning];

        NSString *applicationPath = nil;

        // Skip the program name (argv[0])
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];

            // Handle only help and version options
            if ([arg hasPrefix:@"-"]) {
                if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
                    printUsage();
                    return 0;
                } else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"--verbose"]) {
                    [WCProtector setLogLevel:WCLogLevelDebug];
                } else {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                                 category:@"General"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Unknown option: %@", arg];
                    printUsage();
                    return 1;
                }
            } else {
                // Non-option argument is the application path
                if (applicationPath == nil) {
                    applicationPath = arg;
                } else {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                                 category:@"General"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Multiple application paths specified"];
                    printUsage();
                    return 1;
                }
            }
        }

        // Validate arguments
        if (applicationPath == nil) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"No application path specified"];
            printUsage();
            return 1;
        }

        // Verify application path exists and executable can be found
        printf("[WindowControlInjector] Resolving application path: %s\n", [applicationPath UTF8String]);
        NSString *executablePath = resolveApplicationPath(applicationPath, YES); // Force debug mode for path resolution
        if (executablePath == nil) {
            printf("[WindowControlInjector] ERROR: Could not resolve executable path for: %s\n", [applicationPath UTF8String]);
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Invalid application path: %@", applicationPath];
            return 1;
        }

        printf("[WindowControlInjector] Using application: %s\n", [applicationPath UTF8String]);
        printf("[WindowControlInjector] Found executable at: %s\n", [executablePath UTF8String]);
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"General"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Using application: %@", applicationPath];

        // Initialize the WindowControlInjector
        printf("[WindowControlInjector] Initializing WindowControlInjector...\n");
        if (!WCProtectorInitialize()) {
            printf("[WindowControlInjector] ERROR: Failed to initialize WindowControlInjector\n");
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to initialize WindowControlInjector"];
            return 1;
        }
        printf("[WindowControlInjector] Successfully initialized WindowControlInjector\n");

        // Apply protection with all features enabled by default
        printf("[WindowControlInjector] Applying protection to application...\n");
        NSError *error = nil;
        BOOL success = WCProtectApplication(applicationPath, &error);

        if (!success) {
            if (error) {
                printf("[WindowControlInjector] ERROR: Protection failed: %s\n", [[error localizedDescription] UTF8String]);
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Protection failed: %@", [error localizedDescription]];

                // Provide additional diagnostic information
                if ([error.domain isEqualToString:WCProtectorErrorDomain]) {
                    switch (error.code) {
                        case 100:
                            printf("[WindowControlInjector] Diagnosis: Application path is nil\n");
                            break;
                        case 101:
                            printf("[WindowControlInjector] Diagnosis: Application not found or not accessible\n");
                            break;
                        case 102:
                        case 103:
                            printf("[WindowControlInjector] Diagnosis: Issue with injector dylib\n");
                            break;
                        case 104:
                        case 105:
                        case 106:
                            printf("[WindowControlInjector] Diagnosis: Failed to launch application. This might be due to:\n");
                            printf("[WindowControlInjector]   - macOS security restrictions (System Integrity Protection)\n");
                            printf("[WindowControlInjector]   - Application has special launch requirements\n");
                            printf("[WindowControlInjector]   - Environment variables not being passed correctly\n");
                            break;
                        default:
                            printf("[WindowControlInjector] Diagnosis: Unknown error\n");
                            break;
                    }
                }
            } else {
                printf("[WindowControlInjector] ERROR: Protection failed for unknown reason\n");
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Protection failed for unknown reason"];
            }
            return 1;
        }

        printf("[WindowControlInjector] Successfully protected application: %s\n", [applicationPath UTF8String]);
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"General"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully protected application: %@", applicationPath];
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
    printf("  -h, --help         Show this help message\n\n");

    printf("Examples:\n");
    printf("  ./build/injector /Applications/TextEdit.app\n");
    printf("  ./build/injector -v /Applications/Calculator.app\n");
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
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"General"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Resolving application path: %@", path];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"General"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Normalized path: %@", normalizedPath];
    }

    // Check if the path is valid
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:normalizedPath isDirectory:&isDirectory];

    if (!exists) {
        if (debugMode) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Path does not exist: %@", normalizedPath];
        }
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"General"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Application not found at path: %@", path];
        return nil;
    }

    // 2. Handle symlinks
    NSString *resolvedPath = normalizedPath;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:normalizedPath error:nil];
    if (fileAttributes && fileAttributes[NSFileType] == NSFileTypeSymbolicLink) {
        NSError *linkError = nil;
        resolvedPath = [fileManager destinationOfSymbolicLinkAtPath:normalizedPath error:&linkError];

        if (linkError || !resolvedPath) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to resolve symlink: %@", normalizedPath];
            if (linkError) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Error: %@", [linkError localizedDescription]];
            }
            return nil;
        }

        if (debugMode) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Resolved symlink to: %@", resolvedPath];
        }

        // Check if the resolved path exists
        exists = [fileManager fileExistsAtPath:resolvedPath isDirectory:&isDirectory];
        if (!exists) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Symlink destination does not exist: %@", resolvedPath];
            return nil;
        }
    }

    // 3. If it's a directory, try to handle it as an app bundle or find an executable
    if (isDirectory) {
        if (debugMode) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Path is a directory: %@", resolvedPath];
        }

        // 3.1 Check if it has the .app extension (common but not required)
        BOOL isAppBundle = [resolvedPath.pathExtension isEqualToString:@"app"];
        if (!isAppBundle) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Path doesn't have .app extension: %@", resolvedPath];
        }

        // 3.2 Try standard app bundle structure
        NSString *contentsPath = [resolvedPath stringByAppendingPathComponent:@"Contents"];
        NSString *macOSPath = [contentsPath stringByAppendingPathComponent:@"MacOS"];
        NSString *infoPlistPath = [contentsPath stringByAppendingPathComponent:@"Info.plist"];

        // 3.3 Try to get executable from Info.plist if it exists
        if ([fileManager fileExistsAtPath:infoPlistPath]) {
            if (debugMode) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Found Info.plist at: %@", infoPlistPath];
            }

            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
            NSString *executableName = infoPlist[@"CFBundleExecutable"];

            if (executableName) {
                if (debugMode) {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                 category:@"General"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Found CFBundleExecutable in Info.plist: %@", executableName];
                }

                // Standard location
                NSString *executablePath = [macOSPath stringByAppendingPathComponent:executableName];
                [attemptedPaths addObject:executablePath];

                if ([fileManager fileExistsAtPath:executablePath] &&
                    [fileManager isExecutableFileAtPath:executablePath]) {
                    if (debugMode) {
                        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                     category:@"General"
                                                         file:__FILE__
                                                         line:__LINE__
                                                     function:__PRETTY_FUNCTION__
                                                       format:@"Found executable at standard location: %@", executablePath];
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
                        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                     category:@"General"
                                                         file:__FILE__
                                                         line:__LINE__
                                                     function:__PRETTY_FUNCTION__
                                                       format:@"Found executable directly in Contents: %@", executablePath];
                    }
                    return executablePath;
                }

                // Try at app bundle root
                executablePath = [resolvedPath stringByAppendingPathComponent:executableName];
                [attemptedPaths addObject:executablePath];
                if ([fileManager fileExistsAtPath:executablePath] &&
                    [fileManager isExecutableFileAtPath:executablePath]) {
                    if (debugMode) {
                        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                     category:@"General"
                                                         file:__FILE__
                                                         line:__LINE__
                                                     function:__PRETTY_FUNCTION__
                                                       format:@"Found executable at app bundle root: %@", executablePath];
                    }
                    return executablePath;
                }
            } else {
                if (debugMode) {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                                 category:@"General"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"No CFBundleExecutable found in Info.plist"];
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
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                 category:@"General"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Found executable using app name: %@", executablePath];
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
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                 category:@"General"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Searching for any executable in MacOS directory"];
                }

                for (NSString *item in macOSContents) {
                    NSString *itemPath = [macOSPath stringByAppendingPathComponent:item];
                    [attemptedPaths addObject:itemPath];

                    if ([fileManager isExecutableFileAtPath:itemPath]) {
                        if (debugMode) {
                            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                                         category:@"General"
                                                             file:__FILE__
                                                             line:__LINE__
                                                         function:__PRETTY_FUNCTION__
                                                           format:@"Found executable in MacOS directory: %@", itemPath];
                        }
                        return itemPath;
                    }
                }
            }
        }

        // 3.6 Check if the directory itself is executable (rare)
        if ([fileManager isExecutableFileAtPath:resolvedPath]) {
            if (debugMode) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Directory itself is executable: %@", resolvedPath];
            }
            return resolvedPath;
        }

        // 3.7 Nothing worked, provide detailed error
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"General"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Could not find executable in application bundle: %@", resolvedPath];
        if (debugMode) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Attempted paths:"];
            for (NSString *attempt in attemptedPaths) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"  - %@", attempt];
            }
        }

        return nil;
    } else {
        // 4. It's a file, check if it's executable
        if (debugMode) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Path is a file: %@", resolvedPath];
        }

        if ([fileManager isExecutableFileAtPath:resolvedPath]) {
            if (debugMode) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                             category:@"General"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"File is executable: %@", resolvedPath];
            }
            return resolvedPath;
        } else {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"General"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"File is not executable: %@", resolvedPath];
            return nil;
        }
    }
}
