/**
 * @file unfocusable.h
 * @brief Unfocusable profile for WindowControlInjector
 *
 * This file defines the Unfocusable profile, which prevents windows from
 * receiving keyboard focus.
 */

#ifndef UNFOCUSABLE_PROFILE_H
#define UNFOCUSABLE_PROFILE_H

#import <Foundation/Foundation.h>
#import "../include/profiles.h"

/**
 * @brief Unfocusable profile class for WindowControlInjector
 *
 * This profile prevents windows from receiving keyboard focus by modifying
 * canBecomeKey and canBecomeMain properties.
 */
@interface WCUnfocusableProfile : NSObject <WCProfile>

/**
 * @brief Create a new Unfocusable profile
 *
 * @return A new Unfocusable profile instance
 */
+ (instancetype)profile;

@end

#endif /* UNFOCUSABLE_PROFILE_H */
