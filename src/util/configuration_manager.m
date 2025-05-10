/**
 * @file configuration_manager.m
 * @brief Implementation of centralized configuration management
 */

#import "configuration_manager.h"
#import "logger.h" // Using the standard logger with compatible macros
#import "error_manager.h"
#import "path_resolver.h"

// Environment variable names
static NSString *const kWCEnvLogLevel = @"WCI_LOG_LEVEL";
static NSString *const kWCEnvHideDock = @"WCI_HIDE_DOCK";
static NSString *const kWCEnvPreventScreenCapture = @"WCI_PREVENT_SCREEN_CAPTURE";
static NSString *const kWCEnvWindowLevel = @"WCI_WINDOW_LEVEL";
static NSString *const kWCEnvActivationPolicy = @"WCI_ACTIVATION_POLICY";
static NSString *const kWCEnvConfigPath = @"WCI_CONFIG_PATH";

// JSON keys for serialization
static NSString *const kWCJsonWindowLevel = @"windowLevel";
static NSString *const kWCJsonWindowSharingType = @"windowSharingType";
static NSString *const kWCJsonActivationPolicy = @"activationPolicy";
static NSString *const kWCJsonPresentationOptions = @"presentationOptions";
static NSString *const kWCJsonWindowIgnoresMouseEvents = @"windowIgnoresMouseEvents";
static NSString *const kWCJsonWindowCanBecomeKey = @"windowCanBecomeKey";
static NSString *const kWCJsonWindowCanBecomeMain = @"windowCanBecomeMain";
static NSString *const kWCJsonWindowHasShadow = @"windowHasShadow";
static NSString *const kWCJsonWindowAlphaValue = @"windowAlphaValue";
static NSString *const kWCJsonWindowStyleMask = @"windowStyleMask";
static NSString *const kWCJsonWindowCollectionBehavior = @"windowCollectionBehavior";
static NSString *const kWCJsonWindowAcceptsMouseMovedEvents = @"windowAcceptsMouseMovedEvents";
static NSString *const kWCJsonLogFilePath = @"logFilePath";
static NSString *const kWCJsonLogLevel = @"logLevel";
static NSString *const kWCJsonEnabledInterceptors = @"enabledInterceptors";
static NSString *const kWCJsonOptions = @"options";

@implementation WCConfigurationManager

#pragma mark - Initialization and Singleton Pattern

+ (instancetype)sharedManager {
    static WCConfigurationManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance loadFromEnvironment];
    });
    return instance;
}

+ (instancetype)defaultConfiguration {
    return [[self alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        [self resetToDefaults];
    }
    return self;
}

#pragma mark - Option Management

- (BOOL)isOptionEnabled:(WCConfigurationOptions)option {
    return (_options & option) == option;
}

- (void)enableOption:(WCConfigurationOptions)option {
    _options |= option;
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Enabled configuration option: %lu", (unsigned long)option];
    [self applyOptions];
}

- (void)disableOption:(WCConfigurationOptions)option {
    _options &= ~option;
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:WCLogCategoryGeneral
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Disabled configuration option: %lu", (unsigned long)option];
    [self applyOptions];
}

- (void)applyOptions {
    // Convert options to specific settings

    // Window level for always-on-top
    if ([self isOptionEnabled:WCConfigurationOptionMakeAlwaysOnTop]) {
        self.windowLevel = NSFloatingWindowLevel;
    } else {
        self.windowLevel = NSNormalWindowLevel;
    }

    // Prevent screen capture
    if ([self isOptionEnabled:WCConfigurationOptionPreventScreenCapture]) {
        self.windowSharingType = NSWindowSharingNone;
    } else {
        self.windowSharingType = NSWindowSharingReadOnly;
    }

    // Hide from Dock
    if ([self isOptionEnabled:WCConfigurationOptionHideDock]) {
        self.applicationActivationPolicy = NSApplicationActivationPolicyAccessory;
        self.presentationOptions |= NSApplicationPresentationHideDock;
    } else {
        self.applicationActivationPolicy = NSApplicationActivationPolicyRegular;
        self.presentationOptions &= ~NSApplicationPresentationHideDock;
    }

    // Disable Force Quit
    if ([self isOptionEnabled:WCConfigurationOptionDisableForceQuit]) {
        self.presentationOptions |= NSApplicationPresentationDisableForceQuit;
    } else {
        self.presentationOptions &= ~NSApplicationPresentationDisableForceQuit;
    }

    // Hide from application switcher (Cmd+Tab)
    // Note: This is primarily controlled by activation policy (NSApplicationActivationPolicyAccessory)
    // but we can make the application even less visible by using additional presentation options
    if ([self isOptionEnabled:WCConfigurationOptionHideFromSwitcher]) {
        // Make the application less visible overall
        self.presentationOptions |= NSApplicationPresentationAutoHideDock;
        self.presentationOptions |= NSApplicationPresentationAutoHideMenuBar;
        // Set the activation policy to prohibit from appearing in the switcher
        self.applicationActivationPolicy = NSApplicationActivationPolicyProhibited;
    } else {
        self.presentationOptions &= ~NSApplicationPresentationAutoHideDock;
        self.presentationOptions &= ~NSApplicationPresentationAutoHideMenuBar;
        // Only reset to accessory if hide dock is enabled, otherwise regular
        if ([self isOptionEnabled:WCConfigurationOptionHideDock]) {
            self.applicationActivationPolicy = NSApplicationActivationPolicyAccessory;
        } else {
            self.applicationActivationPolicy = NSApplicationActivationPolicyRegular;
        }
    }

    // Debug logging
    if ([self isOptionEnabled:WCConfigurationOptionEnableDebugLogging]) {
        self.logLevel = WCLogLevelDebug;
    } else {
        self.logLevel = WCLogLevelInfo;
    }
}

#pragma mark - Configuration Loading and Saving

- (void)loadFromEnvironment {
    NSDictionary *env = [[NSProcessInfo processInfo] environment];

    // Check for config file path first
    NSString *configPath = env[kWCEnvConfigPath];
    if (configPath && [[NSFileManager defaultManager] fileExistsAtPath:configPath]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:WCLogCategoryConfiguration
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Loading configuration from file: %@", configPath];
        if ([self loadFromFile:configPath]) {
            // Successfully loaded from file, no need to process environment variables
            return;
        }
    }

    // Process individual environment variables
    NSString *logLevelStr = env[kWCEnvLogLevel];
    if (logLevelStr) {
        self.logLevel = [logLevelStr integerValue];
    }

    NSString *hideDockStr = env[kWCEnvHideDock];
    if (hideDockStr) {
        if ([hideDockStr boolValue]) {
            [self enableOption:WCConfigurationOptionHideDock];
        } else {
            [self disableOption:WCConfigurationOptionHideDock];
        }
    }

    NSString *preventScreenCaptureStr = env[kWCEnvPreventScreenCapture];
    if (preventScreenCaptureStr) {
        if ([preventScreenCaptureStr boolValue]) {
            [self enableOption:WCConfigurationOptionPreventScreenCapture];
        } else {
            [self disableOption:WCConfigurationOptionPreventScreenCapture];
        }
    }

    NSString *windowLevelStr = env[kWCEnvWindowLevel];
    if (windowLevelStr) {
        self.windowLevel = [windowLevelStr integerValue];
    }

    NSString *activationPolicyStr = env[kWCEnvActivationPolicy];
    if (activationPolicyStr) {
        self.applicationActivationPolicy = [activationPolicyStr integerValue];
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryConfiguration
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Loaded configuration from environment"];
}

- (BOOL)saveToFile:(NSString *)path {
    // Create dictionary representation
    NSMutableDictionary *config = [NSMutableDictionary dictionary];

    config[kWCJsonWindowLevel] = @(self.windowLevel);
    config[kWCJsonWindowSharingType] = @(self.windowSharingType);
    config[kWCJsonActivationPolicy] = @(self.applicationActivationPolicy);
    config[kWCJsonPresentationOptions] = @(self.presentationOptions);
    config[kWCJsonWindowIgnoresMouseEvents] = @(self.windowIgnoresMouseEvents);
    config[kWCJsonWindowCanBecomeKey] = @(self.windowCanBecomeKey);
    config[kWCJsonWindowCanBecomeMain] = @(self.windowCanBecomeMain);
    config[kWCJsonWindowHasShadow] = @(self.windowHasShadow);
    config[kWCJsonWindowAlphaValue] = @(self.windowAlphaValue);
    config[kWCJsonWindowStyleMask] = @(self.windowStyleMask);
    config[kWCJsonWindowCollectionBehavior] = @(self.windowCollectionBehavior);
    config[kWCJsonWindowAcceptsMouseMovedEvents] = @(self.windowAcceptsMouseMovedEvents);
    config[kWCJsonLogFilePath] = self.logFilePath;
    config[kWCJsonLogLevel] = @(self.logLevel);
    config[kWCJsonEnabledInterceptors] = @(self.enabledInterceptors);
    config[kWCJsonOptions] = @(self.options);

    // Convert to JSON data
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:config
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

    if (!jsonData) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryConfiguration
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to serialize configuration: %@", [error localizedDescription]];
        return NO;
    }

    // Create directory if it doesn't exist
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![directory isEqualToString:path]) {
        [[WCPathResolver sharedResolver] createDirectoryAtPath:directory
                                          createIntermediates:YES
                                                        error:&error];
    }

    // Write to file
    BOOL success = [jsonData writeToFile:path options:NSDataWritingAtomic error:&error];

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:WCLogCategoryConfiguration
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Saved configuration to file: %@", path];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryConfiguration
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to save configuration to file %@: %@", path, [error localizedDescription]];
    }

    return success;
}

- (BOOL)loadFromFile:(NSString *)path {
    // Check if file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryConfiguration
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Configuration file not found: %@", path];
        return NO;
    }

    // Read data from file
    NSError *error = nil;
    NSData *jsonData = [NSData dataWithContentsOfFile:path options:0 error:&error];

    if (!jsonData) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryConfiguration
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to read configuration file %@: %@", path, [error localizedDescription]];
        return NO;
    }

    // Parse JSON
    NSDictionary *config = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

    if (!config || ![config isKindOfClass:[NSDictionary class]]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:WCLogCategoryConfiguration
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to parse configuration file %@: %@", path, [error localizedDescription]];
        return NO;
    }

    // Apply settings
    if (config[kWCJsonWindowLevel]) {
        self.windowLevel = [config[kWCJsonWindowLevel] integerValue];
    }

    if (config[kWCJsonWindowSharingType]) {
        self.windowSharingType = [config[kWCJsonWindowSharingType] integerValue];
    }

    if (config[kWCJsonActivationPolicy]) {
        self.applicationActivationPolicy = [config[kWCJsonActivationPolicy] integerValue];
    }

    if (config[kWCJsonPresentationOptions]) {
        self.presentationOptions = [config[kWCJsonPresentationOptions] unsignedIntegerValue];
    }

    if (config[kWCJsonWindowIgnoresMouseEvents]) {
        self.windowIgnoresMouseEvents = [config[kWCJsonWindowIgnoresMouseEvents] boolValue];
    }

    if (config[kWCJsonWindowCanBecomeKey]) {
        self.windowCanBecomeKey = [config[kWCJsonWindowCanBecomeKey] boolValue];
    }

    if (config[kWCJsonWindowCanBecomeMain]) {
        self.windowCanBecomeMain = [config[kWCJsonWindowCanBecomeMain] boolValue];
    }

    if (config[kWCJsonWindowHasShadow]) {
        self.windowHasShadow = [config[kWCJsonWindowHasShadow] boolValue];
    }

    if (config[kWCJsonWindowAlphaValue]) {
        self.windowAlphaValue = [config[kWCJsonWindowAlphaValue] doubleValue];
    }

    if (config[kWCJsonWindowStyleMask]) {
        self.windowStyleMask = [config[kWCJsonWindowStyleMask] unsignedIntegerValue];
    }

    if (config[kWCJsonWindowCollectionBehavior]) {
        self.windowCollectionBehavior = [config[kWCJsonWindowCollectionBehavior] unsignedIntegerValue];
    }

    if (config[kWCJsonWindowAcceptsMouseMovedEvents]) {
        self.windowAcceptsMouseMovedEvents = [config[kWCJsonWindowAcceptsMouseMovedEvents] boolValue];
    }

    if (config[kWCJsonLogFilePath]) {
        self.logFilePath = config[kWCJsonLogFilePath];
    }

    if (config[kWCJsonLogLevel]) {
        self.logLevel = [config[kWCJsonLogLevel] integerValue];
    }

    if (config[kWCJsonEnabledInterceptors]) {
        self.enabledInterceptors = [config[kWCJsonEnabledInterceptors] unsignedIntegerValue];
    }

    if (config[kWCJsonOptions]) {
        self.options = [config[kWCJsonOptions] unsignedIntegerValue];
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryConfiguration
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Loaded configuration from file: %@", path];
    return YES;
}

#pragma mark - Reset to Defaults

- (void)resetToDefaults {
    // Set default values for all properties
    self.windowLevel = NSFloatingWindowLevel;
    self.windowSharingType = NSWindowSharingNone;
    self.applicationActivationPolicy = NSApplicationActivationPolicyAccessory;
    self.presentationOptions = NSApplicationPresentationHideDock | NSApplicationPresentationDisableForceQuit;
    self.windowIgnoresMouseEvents = NO;
    self.windowCanBecomeKey = NO;
    self.windowCanBecomeMain = NO;
    self.windowHasShadow = NO;
    self.windowAlphaValue = 1.0;
    self.windowStyleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskNonactivatingPanel;
    self.windowCollectionBehavior = NSWindowCollectionBehaviorParticipatesInCycle | NSWindowCollectionBehaviorManaged;
    self.windowAcceptsMouseMovedEvents = YES;
    self.logFilePath = [[WCPathResolver sharedResolver] logFilePath];
    self.logLevel = WCLogLevelInfo;
    self.enabledInterceptors = UINT_MAX; // All interceptors enabled by default
    self.options = WCConfigurationOptionDefault;

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:WCLogCategoryConfiguration
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Reset configuration to defaults"];
}

@end
