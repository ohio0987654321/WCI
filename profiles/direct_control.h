/**
 * @file direct_control.h
 * @brief Header for the DirectControl profile using enhanced window control techniques
 */

#ifndef DIRECT_CONTROL_H
#define DIRECT_CONTROL_H

#import "../include/profiles.h"

/**
 * @class WCDirectControlProfile
 * @brief Profile that uses direct Objective-C messaging for enhanced window control
 *
 * This profile provides advanced window control by directly working with NSWindow
 * and NSApplication instances, using techniques that aren't limited by property
 * overriding. It implements stronger screen recording protection, window behavior
 * control, and stealth functionality through direct message sending.
 */
@interface WCDirectControlProfile : NSObject <WCProfile>

/**
 * Factory method to create a profile instance
 * @return A new instance of the DirectControl profile
 */
+ (instancetype)profile;

/**
 * Enable window interaction (allow windows to receive focus)
 * This allows windows to become key and main windows, enabling
 * normal interaction while maintaining screen recording protection
 */
+ (void)enableWindowInteraction;

/**
 * Disable window interaction (prevent windows from receiving focus)
 * This prevents windows from becoming key and main windows, making
 * them "pass-through" for keyboard input while still visible
 */
+ (void)disableWindowInteraction;

/**
 * Set window interaction state
 * @param enable YES to allow windows to receive focus, NO to prevent focus
 */
+ (void)setWindowInteraction:(BOOL)enable;

/**
 * Get current window interaction state
 * @return YES if windows can receive focus, NO otherwise
 */
+ (BOOL)windowInteractionEnabled;

@end

#endif /* DIRECT_CONTROL_H */
