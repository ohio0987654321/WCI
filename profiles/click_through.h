/**
 * @file click_through.h
 * @brief Click Through profile for WindowControlInjector
 *
 * This file defines the Click Through profile, which makes windows click-through
 * by allowing mouse events to pass through to underlying windows.
 */

#ifndef CLICK_THROUGH_PROFILE_H
#define CLICK_THROUGH_PROFILE_H

#import <Foundation/Foundation.h>
#import "../include/profiles.h"

/**
 * @brief Click Through profile class for WindowControlInjector
 *
 * This profile makes windows click-through by setting ignoresMouseEvents to YES,
 * allowing mouse events to pass through to underlying windows.
 */
@interface WCClickThroughProfile : NSObject <WCProfile>

/**
 * @brief Create a new Click Through profile
 *
 * @return A new Click Through profile instance
 */
+ (instancetype)profile;

@end

#endif /* CLICK_THROUGH_PROFILE_H */
