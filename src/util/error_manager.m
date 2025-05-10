/**
 * @file error_manager.m
 * @brief Implementation of enhanced error handling framework for WindowControlInjector
 */

#import "error_manager.h"
#import "logger.h"

// Define the error domain
NSString * const WCErrorDomain = @"com.windowcontrolinjector.error";

// User info keys for extended error properties
static NSString * const WCErrorCategoryKey = @"WCErrorCategory";
static NSString * const WCErrorDetailsKey = @"WCErrorDetails";
static NSString * const WCErrorSuggestionKey = @"WCErrorSuggestion";

@implementation WCError

#pragma mark - Factory Methods

+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message {
    return [self errorWithCategory:category
                             code:code
                          message:message
                          details:nil];
}

+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message
                         details:(NSDictionary *)details {
    return [self errorWithCategory:category
                             code:code
                          message:message
                          details:details
                       suggestion:nil];
}

+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message
                         details:(NSDictionary *)details
                      suggestion:(NSString *)suggestion {
    return [self errorWithCategory:category
                             code:code
                          message:message
                          details:details
                       suggestion:suggestion
                  underlyingError:nil];
}

+ (instancetype)errorWithCategory:(WCErrorCategory)category
                            code:(NSInteger)code
                         message:(NSString *)message
                         details:(NSDictionary *)details
                      suggestion:(NSString *)suggestion
                 underlyingError:(NSError *)underlyingError {

    // Create the user info dictionary with standard and extended properties
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

    // Add the error message
    if (message) {
        userInfo[NSLocalizedDescriptionKey] = message;
    }

    // Add error category
    userInfo[WCErrorCategoryKey] = @(category);

    // Add details if provided
    if (details) {
        userInfo[WCErrorDetailsKey] = details;
    }

    // Add suggestion if provided
    if (suggestion) {
        userInfo[WCErrorSuggestionKey] = suggestion;
        userInfo[NSLocalizedRecoverySuggestionErrorKey] = suggestion;
    }

    // Add underlying error if provided
    if (underlyingError) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }

    // Add failure reason based on the error category
    NSString *failureReason = [self failureReasonForCategory:category code:code];
    if (failureReason) {
        userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;
    }

    // Log the error creation
    if (details) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Creating error [%ld:%ld]: %@ - Details: %@",
                                              (long)category, (long)code, message, details];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                     category:WCLogCategoryGeneral
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Creating error [%ld:%ld]: %@",
                                              (long)category, (long)code, message];
    }

    // Create and return the error
    return [[self alloc] initWithDomain:WCErrorDomain code:code userInfo:userInfo];
}

#pragma mark - Helper Methods

+ (NSString *)failureReasonForCategory:(WCErrorCategory)category code:(NSInteger)code {
    // Define failure reasons for specific error codes
    switch (category) {
        case WCErrorCategoryLaunch:
            return @"Application launch failed";

        case WCErrorCategoryInjection:
            return @"Dylib injection failed";

        case WCErrorCategoryConfiguration:
            return @"Configuration error";

        case WCErrorCategoryInterception:
            return @"Method interception failed";

        case WCErrorCategoryRuntime:
            return @"Runtime error";

        case WCErrorCategoryPath:
            return @"Path resolution failed";

        case WCErrorCategorySystem:
            return @"System error";

        case WCErrorCategoryGeneral:
        default:
            return @"General error";
    }
}

+ (NSString *)categoryNameForCategory:(WCErrorCategory)category {
    switch (category) {
        case WCErrorCategoryLaunch:
            return @"Launch";

        case WCErrorCategoryInjection:
            return @"Injection";

        case WCErrorCategoryConfiguration:
            return @"Configuration";

        case WCErrorCategoryInterception:
            return @"Interception";

        case WCErrorCategoryRuntime:
            return @"Runtime";

        case WCErrorCategoryPath:
            return @"Path";

        case WCErrorCategorySystem:
            return @"System";

        case WCErrorCategoryGeneral:
        default:
            return @"General";
    }
}

#pragma mark - Accessor Methods

- (WCErrorCategory)errorCategory {
    NSNumber *categoryValue = self.userInfo[WCErrorCategoryKey];
    return categoryValue ? [categoryValue integerValue] : WCErrorCategoryGeneral;
}

- (NSDictionary *)errorDetails {
    return self.userInfo[WCErrorDetailsKey];
}

- (NSString *)errorSuggestion {
    return self.userInfo[WCErrorSuggestionKey];
}

#pragma mark - Description Methods

- (NSString *)diagnosticDescription {
    NSMutableString *description = [NSMutableString string];

    // Add basic error information
    [description appendFormat:@"Error [%@:%ld]: %@",
                 [WCError categoryNameForCategory:self.errorCategory],
                 (long)self.code,
                 self.localizedDescription];

    // Add failure reason if available
    if (self.localizedFailureReason) {
        [description appendFormat:@"\nReason: %@", self.localizedFailureReason];
    }

    // Add details if available
    NSDictionary *details = [self errorDetails];
    if (details.count > 0) {
        [description appendString:@"\nDetails:"];
        for (NSString *key in [details.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [description appendFormat:@"\n  - %@: %@", key, details[key]];
        }
    }

    // Add suggestion if available
    NSString *suggestion = [self errorSuggestion];
    if (suggestion) {
        [description appendFormat:@"\nSuggestion: %@", suggestion];
    }

    // Add underlying error if available
    NSError *underlyingError = self.userInfo[NSUnderlyingErrorKey];
    if (underlyingError) {
        if ([underlyingError isKindOfClass:[WCError class]]) {
            WCError *wcError = (WCError *)underlyingError;
            [description appendFormat:@"\nUnderlying Error: %@", [wcError diagnosticDescription]];
        } else {
            [description appendFormat:@"\nUnderlying Error: [%@:%ld] %@",
                         underlyingError.domain,
                         (long)underlyingError.code,
                         underlyingError.localizedDescription];
        }
    }

    return description;
}

- (NSString *)userFriendlyDescription {
    NSMutableString *description = [NSMutableString string];

    // Start with the basic error message
    [description appendString:self.localizedDescription];

    // Add the suggestion if available
    NSString *suggestion = [self errorSuggestion];
    if (suggestion) {
        [description appendFormat:@"\n\nSuggestion: %@", suggestion];
    }

    return description;
}

#pragma mark - Category Checking

- (BOOL)isInCategory:(WCErrorCategory)category {
    return [self errorCategory] == category;
}

@end
