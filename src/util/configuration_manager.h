/**
 * @file configuration_manager.h
 * @brief Centralized configuration management for WindowControlInjector
 *
 * This file defines a centralized configuration system that provides a single
 * source of truth for all configurable options in the application.
 */

#ifndef CONFIGURATION_MANAGER_H
#define CONFIGURATION_MANAGER_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/**
 * @brief Configuration options for WindowControlInjector
 *
 * Bitwise flags for various configuration options that can be enabled or disabled.
 */
typedef NS_OPTIONS(NSUInteger, WCConfigurationOptions) {
    WCConfigurationOptionNone                  = 0,
    WCConfigurationOptionHideDock              = 1 << 0,  // Hide application from Dock
    WCConfigurationOptionDisableForceQuit      = 1 << 1,  // Disable Force Quit option
    WCConfigurationOptionHideFromSwitcher      = 1 << 2,  // Hide from Cmd+Tab app switcher
    WCConfigurationOptionMakeAlwaysOnTop       = 1 << 3,  // Make windows always on top
    WCConfigurationOptionPreventScreenCapture  = 1 << 4,  // Prevent screen capture/recording
    WCConfigurationOptionEnableDebugLogging    = 1 << 5,  // Enable debug-level logging
    WCConfigurationOptionDefault = WCConfigurationOptionHideDock |
                                   WCConfigurationOptionPreventScreenCapture |
                                   WCConfigurationOptionMakeAlwaysOnTop
};

/**
 * @brief Centralized configuration manager for WindowControlInjector
 *
 * This class manages all configuration settings for the application, providing
 * a single source of truth for all configurable options.
 */
@interface WCConfigurationManager : NSObject

/**
 * @brief Get the shared configuration manager instance
 *
 * @return The shared configuration manager instance
 */
+ (instancetype)sharedManager;

/**
 * @brief Get the default configuration
 *
 * @return A new configuration manager with default settings
 */
+ (instancetype)defaultConfiguration;

/**
 * @brief Window level for protected windows
 *
 * Default is NSFloatingWindowLevel
 */
@property (nonatomic, assign) NSWindowLevel windowLevel;

/**
 * @brief Window sharing type for protected windows
 *
 * Default is NSWindowSharingNone
 */
@property (nonatomic, assign) NSWindowSharingType windowSharingType;

/**
 * @brief Application activation policy
 *
 * Default is NSApplicationActivationPolicyAccessory
 */
@property (nonatomic, assign) NSApplicationActivationPolicy applicationActivationPolicy;

/**
 * @brief Application presentation options
 *
 * Default is NSApplicationPresentationHideDock | NSApplicationPresentationDisableForceQuit
 */
@property (nonatomic, assign) NSApplicationPresentationOptions presentationOptions;

/**
 * @brief Whether windows ignore mouse events
 *
 * Default is NO
 */
@property (nonatomic, assign) BOOL windowIgnoresMouseEvents;

/**
 * @brief Whether windows can become key windows
 *
 * Default is NO
 */
@property (nonatomic, assign) BOOL windowCanBecomeKey;

/**
 * @brief Whether windows can become main windows
 *
 * Default is NO
 */
@property (nonatomic, assign) BOOL windowCanBecomeMain;

/**
 * @brief Whether windows have shadows
 *
 * Default is NO
 */
@property (nonatomic, assign) BOOL windowHasShadow;

/**
 * @brief Window alpha value
 *
 * Default is 1.0
 */
@property (nonatomic, assign) CGFloat windowAlphaValue;

/**
 * @brief Window style mask
 *
 * Default includes NSWindowStyleMaskNonactivatingPanel
 */
@property (nonatomic, assign) NSWindowStyleMask windowStyleMask;

/**
 * @brief Window collection behavior
 *
 * Default includes NSWindowCollectionBehaviorParticipatesInCycle | NSWindowCollectionBehaviorManaged
 */
@property (nonatomic, assign) NSWindowCollectionBehavior windowCollectionBehavior;

/**
 * @brief Whether windows accept mouse moved events
 *
 * Default is YES
 */
@property (nonatomic, assign) BOOL windowAcceptsMouseMovedEvents;

/**
 * @brief Path to the log file
 *
 * Default is ~/wci_debug.log
 */
@property (nonatomic, copy) NSString *logFilePath;

/**
 * @brief Log level
 *
 * Default is WCLogLevelInfo
 */
@property (nonatomic, assign) NSInteger logLevel;

/**
 * @brief Enabled interceptors
 *
 * Default is all interceptors
 */
@property (nonatomic, assign) NSUInteger enabledInterceptors;

/**
 * @brief Configuration options
 *
 * Bitwise mask of WCConfigurationOptions
 */
@property (nonatomic, assign) WCConfigurationOptions options;

/**
 * @brief Check if a configuration option is enabled
 *
 * @param option The option to check
 * @return YES if the option is enabled, NO otherwise
 */
- (BOOL)isOptionEnabled:(WCConfigurationOptions)option;

/**
 * @brief Enable a configuration option
 *
 * @param option The option to enable
 */
- (void)enableOption:(WCConfigurationOptions)option;

/**
 * @brief Disable a configuration option
 *
 * @param option The option to disable
 */
- (void)disableOption:(WCConfigurationOptions)option;

/**
 * @brief Set configuration from environment variables
 *
 * This method reads configuration settings from environment variables.
 */
- (void)loadFromEnvironment;

/**
 * @brief Save configuration to a file
 *
 * @param path The path to save the configuration to
 * @return YES if the configuration was saved successfully, NO otherwise
 */
- (BOOL)saveToFile:(NSString *)path;

/**
 * @brief Load configuration from a file
 *
 * @param path The path to load the configuration from
 * @return YES if the configuration was loaded successfully, NO otherwise
 */
- (BOOL)loadFromFile:(NSString *)path;

/**
 * @brief Reset all settings to defaults
 */
- (void)resetToDefaults;

@end

#endif /* CONFIGURATION_MANAGER_H */
