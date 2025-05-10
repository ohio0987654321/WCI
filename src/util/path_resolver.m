/**
 * @file path_resolver.m
 * @brief Implementation of centralized path resolution
 */

#import "path_resolver.h"
#import "logger.h"
#import "error_manager.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

// Import protector.h to get the WCProtectApplication function
// for use in dylib path resolution
#import "../core/protector.h"

@implementation WCPathResolver {
    // Private instance variables
    NSString *_customDylibPath;
    NSMutableArray<NSString *> *_searchPaths;
    NSString *_logFilePath;
}

#pragma mark - Initialization and Singleton Pattern

+ (instancetype)sharedResolver {
    static WCPathResolver *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _customDylibPath = nil;
        _searchPaths = [NSMutableArray array];
        _logFilePath = [self.homeDirectoryPath stringByAppendingPathComponent:@"wci_debug.log"];
        [self addStandardSearchPaths];
    }
    return self;
}

#pragma mark - Path Resolution

- (NSString *)resolvePathForDylib {
    // First, check if a custom path is set
    if (_customDylibPath) {
        if ([self fileExistsAtPath:_customDylibPath]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                        category:WCLogCategoryGeneral
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Using custom dylib path: %@", _customDylibPath];
            return _customDylibPath;
        }

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Custom dylib path not found: %@", _customDylibPath];
    }

    // Use the current search paths
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in _searchPaths) {
        NSString *dylibPath = [path stringByAppendingPathComponent:@"libwindowcontrolinjector.dylib"];
        if ([fileManager fileExistsAtPath:dylibPath]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                        category:WCLogCategoryGeneral
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Found dylib at: %@", dylibPath];
            return dylibPath;
        }
    }

    // If we can't find it in common locations, try to get the path from the loaded dylibs
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Checking loaded dylibs..."];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        NSString *imagePath = [NSString stringWithUTF8String:path];
        if ([imagePath containsString:@"windowcontrolinjector"]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                        category:WCLogCategoryGeneral
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Found dylib in loaded images: %@", imagePath];
            return imagePath;
        }
    }

    // If we're already running as the dylib, get our own path using a known function in this file
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Attempting to find own dylib path..."];
    Dl_info info;
    if (dladdr((const void *)WCProtectApplication, &info)) {
        NSString *path = [NSString stringWithUTF8String:info.dli_fname];
        if ([path containsString:@"windowcontrolinjector"]) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                        category:WCLogCategoryGeneral
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Found own dylib path: %@", path];
            return path;
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Could not find injector dylib"];
    return nil;
}

- (NSString *)resolveExecutablePathForApplication:(NSString *)applicationPath {
    if (!applicationPath) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Application path is nil"];
        return nil;
    }

    // Check if application exists
    if (![self directoryExistsAtPath:applicationPath]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Application not found at path: %@", applicationPath];
        return nil;
    }

    // Find the executable within the application bundle
    NSString *executablePath = nil;
    NSBundle *appBundle = [NSBundle bundleWithPath:applicationPath];
    if (appBundle) {
        executablePath = [appBundle executablePath];
        if (executablePath) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                        category:WCLogCategoryGeneral
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Found executable using bundle: %@", executablePath];
            return executablePath;
        }
    }

    // Fallback method to find executable
    NSString *contentsPath = [applicationPath stringByAppendingPathComponent:@"Contents"];
    NSString *infoPlistPath = [contentsPath stringByAppendingPathComponent:@"Info.plist"];

    if ([self fileExistsAtPath:infoPlistPath]) {
        NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
        NSString *executableName = infoPlist[@"CFBundleExecutable"];

        if (executableName) {
            executablePath = [contentsPath stringByAppendingPathComponent:@"MacOS"];
            executablePath = [executablePath stringByAppendingPathComponent:executableName];

            if ([self fileExistsAtPath:executablePath]) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                            category:WCLogCategoryGeneral
                                                file:__FILE__
                                                line:__LINE__
                                            function:__PRETTY_FUNCTION__
                                              format:@"Found executable using Info.plist: %@", executablePath];
                return executablePath;
            }
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Could not find executable in application: %@", applicationPath];
    return nil;
}

#pragma mark - Custom Path Management

- (void)setCustomDylibPath:(NSString *)path {
    _customDylibPath = [path copy];
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Set custom dylib path: %@", path];
}

- (NSString *)customDylibPath {
    return _customDylibPath;
}

#pragma mark - Search Path Management

- (NSArray<NSString *> *)searchPaths {
    return [_searchPaths copy];
}

- (void)addSearchPath:(NSString *)path {
    if (path && ![_searchPaths containsObject:path]) {
        [_searchPaths addObject:path];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Added search path: %@", path];
    }
}

- (BOOL)removeSearchPath:(NSString *)path {
    if (path && [_searchPaths containsObject:path]) {
        [_searchPaths removeObject:path];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Removed search path: %@", path];
        return YES;
    }
    return NO;
}

- (void)clearSearchPaths {
    [_searchPaths removeAllObjects];
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Cleared all search paths"];
}

- (void)addStandardSearchPaths {
    // Clear existing paths
    [_searchPaths removeAllObjects];

    // Get the executable directory
    NSString *executablePath = [[NSProcessInfo processInfo] arguments][0];
    NSString *executableDir = [executablePath stringByDeletingLastPathComponent];

    // Add standard paths
    [self addSearchPath:executableDir]; // Same directory as executable
    [self addSearchPath:[executableDir stringByAppendingPathComponent:@"../lib"]]; // ../lib relative to executable
    [self addSearchPath:[executableDir stringByAppendingPathComponent:@".."]]; // .. relative to executable
    [self addSearchPath:@"/usr/local/lib"]; // Standard system location

    // Build directories
    [self addSearchPath:[executableDir stringByAppendingPathComponent:@"../build"]]; // ../build relative to executable
    [self addSearchPath:[[executableDir stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"build"]]; // build relative to parent directory

    // Application Support directories
    [self addSearchPath:[NSString stringWithFormat:@"%@/Library/Application Support/WindowControlInjector", NSHomeDirectory()]]; // User's Application Support
    [self addSearchPath:@"/Library/Application Support/WindowControlInjector"]; // System Application Support

    // Bundle resources
    NSBundle *mainBundle = [NSBundle mainBundle];
    if (mainBundle) {
        [self addSearchPath:[mainBundle bundlePath]]; // Main bundle path
        [self addSearchPath:[mainBundle resourcePath]]; // Resource path
        [self addSearchPath:[[mainBundle bundlePath] stringByAppendingPathComponent:@"lib"]]; // lib in bundle
    }

    // Current working directory
    [self addSearchPath:[self currentWorkingDirectoryPath]]; // Current working directory
    [self addSearchPath:[[self currentWorkingDirectoryPath] stringByAppendingPathComponent:@"build"]]; // build in current working directory

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Added %lu standard search paths", (unsigned long)_searchPaths.count];
}

#pragma mark - Path Utilities

- (NSString *)logFilePath {
    return _logFilePath;
}

- (void)setLogFilePath:(NSString *)path {
    _logFilePath = [path copy];
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Set log file path: %@", path];
}

- (NSString *)homeDirectoryPath {
    return NSHomeDirectory();
}

- (NSString *)currentWorkingDirectoryPath {
    char buffer[PATH_MAX];
    if (getcwd(buffer, sizeof(buffer)) != NULL) {
        return [NSString stringWithUTF8String:buffer];
    }
    return [[NSFileManager defaultManager] currentDirectoryPath];
}

- (NSString *)applicationSupportDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

- (NSString *)temporaryDirectoryPath {
    return NSTemporaryDirectory();
}

#pragma mark - File System Operations

- (BOOL)fileExistsAtPath:(NSString *)path {
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    return exists && !isDirectory;
}

- (BOOL)directoryExistsAtPath:(NSString *)path {
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    return exists && isDirectory;
}

- (BOOL)createDirectoryAtPath:(NSString *)path
         createIntermediates:(BOOL)createIntermediates
                       error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = [fileManager createDirectoryAtPath:path
                         withIntermediateDirectories:createIntermediates
                                          attributes:nil
                                               error:error];

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Created directory at path: %@", path];
    } else if (error && *error) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to create directory at path %@: %@", path, [*error localizedDescription]];
    }

    return success;
}

@end
