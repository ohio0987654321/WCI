/**
 * @file invisible.h
 * @brief Invisible profile for WindowControlInjector
 *
 * This file defines the Invisible profile, which makes windows invisible to
 * screen recording.
 */

#ifndef INVISIBLE_PROFILE_H
#define INVISIBLE_PROFILE_H

#import <Foundation/Foundation.h>
#import "../include/profiles.h"

/**
 * @brief Invisible profile class for WindowControlInjector
 *
 * This profile makes windows invisible to screen recording by setting the
 * window's sharing type to NSWindowSharingNone and applying other properties
 * that help hide the window from screenshots and recordings.
 */
@interface WCInvisibleProfile : NSObject <WCProfile>

/**
 * @brief Create a new Invisible profile
 *
 * @return A new Invisible profile instance
 */
+ (instancetype)profile;

@end

#endif /* INVISIBLE_PROFILE_H */
