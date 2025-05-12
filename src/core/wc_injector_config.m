/**
 * @file wc_injector_config.m
 * @brief Implementation of WCInjectorConfig
 */

#import "wc_injector_config.h"
#import "../util/logger.h"

// Environment variable keys for configuration
static NSString * const kWCOptionsKey = @"WC_OPTIONS";
static NSString * const kWCScanIntervalKey = @"WC_SCAN_INTERVAL";
static NSString * const kWCProtectChildProcessesKey = @"WC_PROTECT_CHILD_PROCESSES";
static NSString * const kWCLogVerboseKey = @"WC_LOG_VERBOSE";

@implementation WCInjectorConfig

#pragma mark - Initialization

- (instancetype)init {
    if (self = [super init]) {
        // Default values
        _options = WCInjectionOptionScreenRecordingProtection;
        _scanInterval = 1.0; // 1 second
        _protectChildProcesses = NO;
        _logVerbose = NO;
    }
    return self;
}

+ (instancetype)defaultConfig {
    WCInjectorConfig *config = [[WCInjectorConfig alloc] init];
    config.options = WCInjectionOptionAll;
    config.protectChildProcesses = YES;
    return config;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        // Parse options
        NSString *optionsStr = dict[kWCOptionsKey];
        if (optionsStr) {
            _options = [optionsStr integerValue];
        } else {
            _options = WCInjectionOptionScreenRecordingProtection;
        }

        // Parse scan interval
        NSString *scanIntervalStr = dict[kWCScanIntervalKey];
        if (scanIntervalStr) {
            _scanInterval = [scanIntervalStr doubleValue];
            // Ensure reasonable value
            if (_scanInterval < 0.1) _scanInterval = 0.1;
            if (_scanInterval > 10.0) _scanInterval = 10.0;
        } else {
            _scanInterval = 1.0;
        }

        // Parse protect child processes flag
        NSString *protectChildProcessesStr = dict[kWCProtectChildProcessesKey];
        if (protectChildProcessesStr) {
            _protectChildProcesses = [protectChildProcessesStr boolValue];
        } else {
            _protectChildProcesses = NO;
        }

        // Parse verbose logging flag
        NSString *logVerboseStr = dict[kWCLogVerboseKey];
        if (logVerboseStr) {
            _logVerbose = [logVerboseStr boolValue];
        } else {
            _logVerbose = NO;
        }

        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"InjectorConfig"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Configuration initialized from dictionary: %@", dict];
    }
    return self;
}

#pragma mark - Dictionary Conversion

- (NSDictionary *)asDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    // Convert options to string
    dict[kWCOptionsKey] = [NSString stringWithFormat:@"%lu", (unsigned long)_options];

    // Convert scan interval to string
    dict[kWCScanIntervalKey] = [NSString stringWithFormat:@"%.2f", _scanInterval];

    // Convert protect child processes flag to string
    dict[kWCProtectChildProcessesKey] = _protectChildProcesses ? @"1" : @"0";

    // Convert verbose logging flag to string
    dict[kWCLogVerboseKey] = _logVerbose ? @"1" : @"0";

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"InjectorConfig"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Configuration as dictionary: %@", dict];

    return dict;
}

#pragma mark - Description

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];

    // Add options
    [description appendString:@"options=("];
    if (_options & WCInjectionOptionScreenRecordingProtection) {
        [description appendString:@"ScreenRecordingProtection "];
    }
    if (_options & WCInjectionOptionDockIconHiding) {
        [description appendString:@"DockIconHiding "];
    }
    if (_options & WCInjectionOptionAlwaysOnTop) {
        [description appendString:@"AlwaysOnTop "];
    }
    if (_options & WCInjectionOptionChildProcessProtection) {
        [description appendString:@"ChildProcessProtection "];
    }
    [description appendString:@")"];

    // Add other properties
    [description appendFormat:@", scanInterval=%.2f", _scanInterval];
    [description appendFormat:@", protectChildProcesses=%@", _protectChildProcesses ? @"YES" : @"NO"];
    [description appendFormat:@", logVerbose=%@", _logVerbose ? @"YES" : @"NO"];

    [description appendString:@">"];
    return description;
}

@end
