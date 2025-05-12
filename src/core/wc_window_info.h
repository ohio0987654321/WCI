/**
 * @file wc_window_info.h
 * @brief Window information abstraction for WindowControlInjector
 *
 * This file defines a class that encapsulates window information
 * in a consistent way regardless of the underlying window system.
 */

#ifndef WC_WINDOW_INFO_H
#define WC_WINDOW_INFO_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../util/wc_cgs_types.h"

/**
 * @brief Class for abstracting window information
 *
 * This class provides a uniform interface for window information
 * regardless of whether the window is an AppKit NSWindow or a
 * non-AppKit window accessed through CGS.
 */
@interface WCWindowInfo : NSObject

/**
 * @brief Window properties
 */
@property (nonatomic, readonly) CGWindowID windowID;
@property (nonatomic, readonly, nullable) NSWindow *nsWindow;  // May be nil for non-AppKit windows
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly, nonnull) NSString *title;
@property (nonatomic, readonly) pid_t ownerPID;
@property (nonatomic, readonly, nonnull) NSString *ownerName;
@property (nonatomic, readonly) BOOL isOnScreen;
@property (nonatomic, readonly) NSWindowLevel level;
@property (nonatomic, readonly) CGSWindowSharingType sharingType;
@property (nonatomic, readonly) BOOL isProtected;

/**
 * @brief Initializers
 */
- (nullable instancetype)initWithWindowID:(CGWindowID)windowID;
- (nullable instancetype)initWithNSWindow:(nonnull NSWindow *)window;
- (nullable instancetype)initWithCGWindowInfo:(nonnull NSDictionary *)windowInfo;

/**
 * @brief Protection methods
 */
- (BOOL)makeInvisibleToScreenRecording;
- (BOOL)setLevel:(NSWindowLevel)level;
- (BOOL)disableStatusBar;
- (BOOL)setWindowTagsForMissionControlVisibility;

/**
 * @brief Get a dictionary representation of this window info
 *
 * @return NSDictionary containing the window information
 */
- (nonnull NSDictionary *)dictionaryRepresentation;

/**
 * @brief Refresh the window information
 *
 * @return YES if successful, NO if the window no longer exists
 */
- (BOOL)refresh;

/**
 * @brief Check if the window still exists
 *
 * @return YES if the window exists, NO otherwise
 */
- (BOOL)exists;

@end

#endif /* WC_WINDOW_INFO_H */
