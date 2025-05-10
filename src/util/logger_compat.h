/**
 * @file logger_compat.h
 * @brief Compatibility layer for the legacy logging system
 */

#ifndef LOGGER_COMPAT_H
#define LOGGER_COMPAT_H

#import "logger.h"

// Define a category on WCLogger to add the compatibility methods
@interface WCLogger (Compatibility)

// Method with the exact signature being used in the macros
- (void)logWithLevel:(WCLogLevel)level
            category:(NSString *)category
                file:(const char *)file
                line:(NSInteger)line
            function:(const char *)function
              format:(NSString *)format, ... NS_FORMAT_FUNCTION(6,7);

@end

// Define new macros that override the ones in logger.h
#undef WCLogError
#undef WCLogWarning
#undef WCLogInfo
#undef WCLogDebug

// Re-define the macros for legacy code
#define WCLogError(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogWarning(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogInfo(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

#define WCLogDebug(category, fmt, ...) \
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug \
                                 category:category \
                                     file:__FILE__ \
                                     line:__LINE__ \
                                 function:__PRETTY_FUNCTION__ \
                                   format:fmt, ##__VA_ARGS__]

#endif /* LOGGER_COMPAT_H */
