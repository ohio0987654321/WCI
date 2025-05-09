/**
 * @file stealth.h
 * @brief Stealth profile for WindowControlInjector
 *
 * This file defines the Stealth profile, which hides applications from the Dock,
 * status bar, and App Switcher.
 */

#ifndef STEALTH_PROFILE_H
#define STEALTH_PROFILE_H

#import <Foundation/Foundation.h>
#import "../include/profiles.h"

/**
 * @brief Stealth profile class for WindowControlInjector
 *
 * This profile hides applications from the Dock, status bar, and App Switcher
 * by modifying the application's activation policy and related properties.
 */
@interface WCStealthProfile : NSObject <WCProfile>

/**
 * @brief Create a new Stealth profile
 *
 * @return A new Stealth profile instance
 */
+ (instancetype)profile;

@end

#endif /* STEALTH_PROFILE_H */
