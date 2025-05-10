/**
 * @file configuration_macros.h
 * @brief Compatibility logging macros for the configuration system
 */

#ifndef CONFIGURATION_MACROS_H
#define CONFIGURATION_MACROS_H

#import "logger.h"

// Legacy-style category macros for backward compatibility
#define WCLogError(category, fmt, ...) \
    do { \
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError \
                                     category:category \
                                         file:__FILE__ \
                                         line:__LINE__ \
                                     function:__PRETTY_FUNCTION__ \
                                       format:fmt, ##__VA_ARGS__]; \
    } while(0)

#define WCLogWarning(category, fmt, ...) \
    do { \
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                     category:category \
                                         file:__FILE__ \
                                         line:__LINE__ \
                                     function:__PRETTY_FUNCTION__ \
                                       format:fmt, ##__VA_ARGS__]; \
    } while(0)

#define WCLogInfo(category, fmt, ...) \
    do { \
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo \
                                     category:category \
                                         file:__FILE__ \
                                         line:__LINE__ \
                                     function:__PRETTY_FUNCTION__ \
                                       format:fmt, ##__VA_ARGS__]; \
    } while(0)

#define WCLogDebug(category, fmt, ...) \
    do { \
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                     category:category \
                                         file:__FILE__ \
                                         line:__LINE__ \
                                     function:__PRETTY_FUNCTION__ \
                                       format:fmt, ##__VA_ARGS__]; \
    } while(0)

#endif /* CONFIGURATION_MACROS_H */
