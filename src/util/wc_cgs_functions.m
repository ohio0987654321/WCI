/**
 * @file wc_cgs_functions.m
 * @brief Implementation of CGS function resolution
 */

#import "wc_cgs_functions.h"
#import "logger.h"
#import <dlfcn.h>

@implementation WCCGSFunctions {
    // Private instance variables
    void *_cgsHandle;
    BOOL _functionsResolved;

    // Private function pointer storage
    CGSDefaultConnectionPtr _cgsDefaultConnection;
    CGSSetWindowSharingStatePtr _cgsSetWindowSharingState;
    CGSGetWindowSharingStatePtr _cgsGetWindowSharingState;
    CGSSetWindowLevelPtr _cgsSetWindowLevel;
    CGSGetWindowLevelPtr _cgsGetWindowLevel;

    // Track which functions we've attempted to resolve
    BOOL _triedToResolveDefaultConnection;
    BOOL _triedToResolveSetWindowSharingState;
    BOOL _triedToResolveGetWindowSharingState;
    BOOL _triedToResolveSetWindowLevel;
    BOOL _triedToResolveGetWindowLevel;
}

#pragma mark - Initialization and Singleton Pattern

+ (instancetype)sharedFunctions {
    static WCCGSFunctions *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _cgsHandle = NULL;
        _functionsResolved = NO;

        // Initialize function pointers to NULL
        _cgsDefaultConnection = NULL;
        _cgsSetWindowSharingState = NULL;
        _cgsGetWindowSharingState = NULL;
        _cgsSetWindowLevel = NULL;
        _cgsGetWindowLevel = NULL;

        // Initialize resolution tracking
        _triedToResolveDefaultConnection = NO;
        _triedToResolveSetWindowSharingState = NO;
        _triedToResolveGetWindowSharingState = NO;
        _triedToResolveSetWindowLevel = NO;
        _triedToResolveGetWindowLevel = NO;

        // Attempt to resolve functions at initialization
        [self resolveAllFunctions];
    }
    return self;
}

#pragma mark - Function Resolution

- (BOOL)resolveAllFunctions {
    if (_functionsResolved) return YES;

    // Load the Core Graphics framework
    _cgsHandle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW);
    if (!_cgsHandle) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to load CoreGraphics framework: %s", dlerror()];
        return NO;
    }

    // Resolve CGSDefaultConnection - this is the minimum required function
    _cgsDefaultConnection = (CGSDefaultConnectionPtr)dlsym(_cgsHandle, "CGSDefaultConnection");
    _triedToResolveDefaultConnection = YES;

    if (!_cgsDefaultConnection) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to resolve CGSDefaultConnection: %s", dlerror()];
        return NO;
    }

    // Resolve CGSSetWindowSharingState
    _cgsSetWindowSharingState = (CGSSetWindowSharingStatePtr)dlsym(_cgsHandle, "CGSSetWindowSharingState");
    _triedToResolveSetWindowSharingState = YES;

    if (!_cgsSetWindowSharingState) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to resolve CGSSetWindowSharingState: %s", dlerror()];
        // Continue anyway - we'll check before using
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully resolved CGSSetWindowSharingState"];
    }

    // Resolve CGSGetWindowSharingState
    _cgsGetWindowSharingState = (CGSGetWindowSharingStatePtr)dlsym(_cgsHandle, "CGSGetWindowSharingState");
    _triedToResolveGetWindowSharingState = YES;

    if (!_cgsGetWindowSharingState) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to resolve CGSGetWindowSharingState: %s", dlerror()];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:@"resolveAllFunctions"
                                       format:@"Successfully resolved CGSGetWindowSharingState"];
    }

    // Resolve CGSSetWindowLevel
    _cgsSetWindowLevel = (CGSSetWindowLevelPtr)dlsym(_cgsHandle, "CGSSetWindowLevel");
    _triedToResolveSetWindowLevel = YES;

    if (!_cgsSetWindowLevel) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to resolve CGSSetWindowLevel: %s", dlerror()];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully resolved CGSSetWindowLevel"];
    }

    // Resolve CGSGetWindowLevel
    _cgsGetWindowLevel = (CGSGetWindowLevelPtr)dlsym(_cgsHandle, "CGSGetWindowLevel");
    _triedToResolveGetWindowLevel = YES;

    if (!_cgsGetWindowLevel) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to resolve CGSGetWindowLevel: %s", dlerror()];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:@"resolveAllFunctions"
                                       format:@"Successfully resolved CGSGetWindowLevel"];
    }

    // We consider initialization successful if at minimum we have the DefaultConnection function
    _functionsResolved = (_cgsDefaultConnection != NULL);

    if (_functionsResolved) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"CGS functions resolved successfully"];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"CGS function resolution failed"];
    }

    return _functionsResolved;
}

#pragma mark - Lazy Function Resolution

// These methods attempt to resolve functions on-demand if they haven't been resolved yet

- (CGSDefaultConnectionPtr)CGSDefaultConnection {
    if (!_cgsDefaultConnection && !_triedToResolveDefaultConnection) {
        _triedToResolveDefaultConnection = YES;
        _cgsDefaultConnection = (CGSDefaultConnectionPtr)dlsym(_cgsHandle, "CGSDefaultConnection");

        if (_cgsDefaultConnection) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"CGS"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Successfully resolved CGSDefaultConnection on demand"];
        }
    }
    return _cgsDefaultConnection;
}

- (CGSSetWindowSharingStatePtr)CGSSetWindowSharingState {
    if (!_cgsSetWindowSharingState && !_triedToResolveSetWindowSharingState) {
        _triedToResolveSetWindowSharingState = YES;
        _cgsSetWindowSharingState = (CGSSetWindowSharingStatePtr)dlsym(_cgsHandle, "CGSSetWindowSharingState");

        if (_cgsSetWindowSharingState) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"CGS"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Successfully resolved CGSSetWindowSharingState on demand"];
        }
    }
    return _cgsSetWindowSharingState;
}

- (CGSGetWindowSharingStatePtr)CGSGetWindowSharingState {
    if (!_cgsGetWindowSharingState && !_triedToResolveGetWindowSharingState) {
        _triedToResolveGetWindowSharingState = YES;
        _cgsGetWindowSharingState = (CGSGetWindowSharingStatePtr)dlsym(_cgsHandle, "CGSGetWindowSharingState");

        if (_cgsGetWindowSharingState) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"CGS"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Successfully resolved CGSGetWindowSharingState on demand"];
        }
    }
    return _cgsGetWindowSharingState;
}

- (CGSSetWindowLevelPtr)CGSSetWindowLevel {
    if (!_cgsSetWindowLevel && !_triedToResolveSetWindowLevel) {
        _triedToResolveSetWindowLevel = YES;
        _cgsSetWindowLevel = (CGSSetWindowLevelPtr)dlsym(_cgsHandle, "CGSSetWindowLevel");

        if (_cgsSetWindowLevel) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"CGS"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Successfully resolved CGSSetWindowLevel on demand"];
        }
    }
    return _cgsSetWindowLevel;
}

- (CGSGetWindowLevelPtr)CGSGetWindowLevel {
    if (!_cgsGetWindowLevel && !_triedToResolveGetWindowLevel) {
        _triedToResolveGetWindowLevel = YES;
        _cgsGetWindowLevel = (CGSGetWindowLevelPtr)dlsym(_cgsHandle, "CGSGetWindowLevel");

        if (_cgsGetWindowLevel) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                         category:@"CGS"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Successfully resolved CGSGetWindowLevel on demand"];
        }
    }
    return _cgsGetWindowLevel;
}

#pragma mark - Availability Checks

- (BOOL)isAvailable {
    return _cgsHandle != NULL && _cgsDefaultConnection != NULL;
}

- (BOOL)canSetWindowSharingState {
    return self.isAvailable && self.CGSSetWindowSharingState != NULL;
}

- (BOOL)canSetWindowLevel {
    return self.isAvailable && self.CGSSetWindowLevel != NULL;
}

#pragma mark - CGS Operation Utilities

- (BOOL)performCGSOperation:(NSString *)operationName
                withWindowID:(CGSWindowID)windowID
                   operation:(CGError (^)(CGSConnectionID cid, CGSWindowID wid))operation {
    if (!self.isAvailable) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot perform %@ - CGS functions unavailable", operationName];
        return NO;
    }

    // Get connection
    CGSConnectionID cid = self.CGSDefaultConnection();
    if (cid == 0) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to get CGS connection for %@", operationName];
        return NO;
    }

    // Perform operation with diagnostics
    CGError error = operation(cid, windowID);

    if (error) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"CGS"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"%@ failed with error %d for window ID %d",
                                             operationName, (int)error, (int)windowID];
        return NO;
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"CGS"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"%@ succeeded for window ID %d",
                                         operationName, (int)windowID];
    return YES;
}

#pragma mark - Cleanup

- (void)dealloc {
    if (_cgsHandle) {
        dlclose(_cgsHandle);
        _cgsHandle = NULL;
    }
}

@end
