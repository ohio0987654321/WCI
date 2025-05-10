/**
 * @file core.h
 * @brief Core profile for WindowControlInjector with minimal features
 *
 * This file defines the Core profile that implements only the essential features:
 * 1. Bypass screen recording/capture
 * 2. Disable dock icon
 * 3. Disable status bar when the app gets focused
 */

#ifndef CORE_PROFILE_H
#define CORE_PROFILE_H

#import <Foundation/Foundation.h>
#import "../include/profiles.h"

/**
 * @brief Core profile class for WindowControlInjector
 *
 * This profile implements only the essential features with no unnecessary visual
 * effects or behavioral modifications:
 * - Screen recording protection
 * - Dock icon hiding
 * - Status bar hiding when focused
 */
@interface WCCoreProfile : NSObject <WCProfile>

/**
 * @brief Create a new Core profile
 *
 * @return A new Core profile instance
 */
+ (instancetype)profile;

@end

#endif /* CORE_PROFILE_H */
