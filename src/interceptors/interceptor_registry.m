/**
 * @file interceptor_registry.m
 * @brief Implementation of the centralized interceptor registry system
 */

#import "interceptor_registry.h"
#import "../util/logger.h"
#import "../util/error_manager.h"

@interface WCInterceptorRegistry ()

// Store registered interceptor classes
@property (nonatomic, strong) NSMutableArray<Class<WCInterceptor>> *registeredInterceptors;

// Track installed interceptors
@property (nonatomic, strong) NSMutableArray<Class<WCInterceptor>> *installedInterceptors;

// Map interceptor classes to option flags
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *interceptorToOptionMap;

@end

@implementation WCInterceptorRegistry

#pragma mark - Initialization

+ (instancetype)sharedRegistry {
    static WCInterceptorRegistry *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _registeredInterceptors = [NSMutableArray array];
        _installedInterceptors = [NSMutableArray array];
        _interceptorToOptionMap = [NSMutableDictionary dictionary];

        [self setupDefaultMappings];
    }
    return self;
}

// Set up default mappings between interceptors and option flags
- (void)setupDefaultMappings {
    // These will be populated when specific interceptors are registered
}

#pragma mark - Registration

- (BOOL)registerInterceptor:(Class<WCInterceptor>)interceptorClass {
    if (!interceptorClass) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot register nil interceptor class"];
        return NO;
    }

    // Check if class properly implements the WCInterceptor protocol
    if (![interceptorClass conformsToProtocol:@protocol(WCInterceptor)]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Class %@ does not conform to WCInterceptor protocol",
                                              NSStringFromClass(interceptorClass)];
        return NO;
    }

    // Check if already registered
    if ([self.registeredInterceptors containsObject:interceptorClass]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Interceptor %@ already registered",
                                              [interceptorClass interceptorName]];
        return YES; // Already registered, so technically successful
    }

    // Add to registered interceptors list
    [self.registeredInterceptors addObject:interceptorClass];

    // Sort by priority if the optional method is implemented
    [self sortRegisteredInterceptorsByPriority];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Successfully registered interceptor: %@",
                                          [interceptorClass interceptorName]];

    return YES;
}

- (BOOL)unregisterInterceptor:(Class<WCInterceptor>)interceptorClass {
    if (!interceptorClass) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot unregister nil interceptor class"];
        return NO;
    }

    // Check if registered
    if (![self.registeredInterceptors containsObject:interceptorClass]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Interceptor %@ not registered",
                                              [interceptorClass interceptorName]];
        return NO;
    }

    // Check if installed - must uninstall first
    if ([self isInterceptorInstalled:interceptorClass]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot unregister installed interceptor %@, uninstall first",
                                              [interceptorClass interceptorName]];
        return NO;
    }

    // Remove from registered interceptors
    [self.registeredInterceptors removeObject:interceptorClass];

    // Remove from option map
    NSString *className = NSStringFromClass(interceptorClass);
    [self.interceptorToOptionMap removeObjectForKey:className];

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Successfully unregistered interceptor: %@",
                                          [interceptorClass interceptorName]];

    return YES;
}

#pragma mark - Installation

- (BOOL)installAllInterceptors {
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Installing all registered interceptors"];

    BOOL success = YES;
    NSMutableArray<Class<WCInterceptor>> *sortedInterceptors = [self sortInterceptorsForInstallation];

    for (Class<WCInterceptor> interceptorClass in sortedInterceptors) {
        if (![self installInterceptor:interceptorClass]) {
            success = NO;
        }
    }

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully installed all interceptors"];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to install all interceptors"];
    }

    return success;
}

- (BOOL)installInterceptorsWithOptions:(WCInterceptorOptions)options {
    if (options == WCInterceptorOptionNone) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"No interceptors specified in options"];
        return YES;
    }

    if (options == WCInterceptorOptionAll) {
        return [self installAllInterceptors];
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Installing interceptors with options: %lu", (unsigned long)options];

    BOOL success = YES;
    NSMutableArray<Class<WCInterceptor>> *interceptorsToInstall = [NSMutableArray array];

    // Find all interceptors matching the options
    for (Class<WCInterceptor> interceptorClass in self.registeredInterceptors) {
        WCInterceptorOptions interceptorOption = [self optionForInterceptor:interceptorClass];
        if (interceptorOption & options) {
            [interceptorsToInstall addObject:interceptorClass];
        }
    }

    // Sort by dependencies and priority
    interceptorsToInstall = [self sortInterceptorsForInstallation:interceptorsToInstall];

    // Install in order
    for (Class<WCInterceptor> interceptorClass in interceptorsToInstall) {
        if (![self installInterceptor:interceptorClass]) {
            success = NO;
        }
    }

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully installed interceptors with options: %lu",
                                              (unsigned long)options];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to install some interceptors with options: %lu",
                                              (unsigned long)options];
    }

    return success;
}

- (BOOL)installInterceptor:(Class<WCInterceptor>)interceptorClass {
    if (!interceptorClass) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot install nil interceptor class"];
        return NO;
    }

    // Check if registered
    if (![self.registeredInterceptors containsObject:interceptorClass]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Interceptor %@ not registered, cannot install",
                                              [interceptorClass interceptorName]];
        return NO;
    }

    // Check if already installed
    if ([self isInterceptorInstalled:interceptorClass]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Interceptor %@ already installed",
                                              [interceptorClass interceptorName]];
        return YES;
    }

    // Check and install dependencies first if the optional method is implemented
    if ([interceptorClass respondsToSelector:@selector(dependencies)]) {
        NSArray<Class> *dependencies = [interceptorClass dependencies];
        for (Class dependencyClass in dependencies) {
            if (![dependencyClass conformsToProtocol:@protocol(WCInterceptor)]) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                             category:@"Interception"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Dependency %@ does not conform to WCInterceptor protocol",
                                                      NSStringFromClass(dependencyClass)];
                return NO;
            }

            if (![self isInterceptorInstalled:dependencyClass]) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                             category:@"Interception"
                                                 file:__FILE__
                                                 line:__LINE__
                                             function:__PRETTY_FUNCTION__
                                               format:@"Installing dependency %@ for %@",
                                                      [dependencyClass interceptorName],
                                                      [interceptorClass interceptorName]];

                if (![self installInterceptor:dependencyClass]) {
                    [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                                 category:@"Interception"
                                                     file:__FILE__
                                                     line:__LINE__
                                                 function:__PRETTY_FUNCTION__
                                                   format:@"Failed to install dependency %@ for %@",
                                                          [dependencyClass interceptorName],
                                                          [interceptorClass interceptorName]];
                    return NO;
                }
            }
        }
    }

    // Install the interceptor
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Installing interceptor: %@",
                                          [interceptorClass interceptorName]];

    BOOL success = [interceptorClass install];

    if (success) {
        [self.installedInterceptors addObject:interceptorClass];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully installed interceptor: %@",
                                              [interceptorClass interceptorName]];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to install interceptor: %@",
                                              [interceptorClass interceptorName]];
    }

    return success;
}

#pragma mark - Uninstallation

- (BOOL)uninstallAllInterceptors {
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Uninstalling all interceptors"];

    BOOL success = YES;

    // Copy array to avoid mutation during enumeration
    NSArray<Class<WCInterceptor>> *interceptorsToUninstall = [self.installedInterceptors copy];

    // Sort in reverse order of installation (dependencies last)
    NSArray<Class<WCInterceptor>> *sortedInterceptors = [[interceptorsToUninstall reverseObjectEnumerator] allObjects];

    for (Class<WCInterceptor> interceptorClass in sortedInterceptors) {
        if (![self uninstallInterceptor:interceptorClass]) {
            success = NO;
        }
    }

    if (success) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully uninstalled all interceptors"];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to uninstall all interceptors completely"];
    }

    return success;
}

- (BOOL)uninstallInterceptor:(Class<WCInterceptor>)interceptorClass {
    if (!interceptorClass) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Cannot uninstall nil interceptor class"];
        return NO;
    }

    // Check if installed
    if (![self isInterceptorInstalled:interceptorClass]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Interceptor %@ not installed",
                                              [interceptorClass interceptorName]];
        return YES; // Not installed, so technically successful
    }

    // Check for reverse dependencies - other interceptors that depend on this one
    NSArray<Class<WCInterceptor>> *dependentInterceptors = [self interceptorsDependingOn:interceptorClass];

    if (dependentInterceptors.count > 0) {
        // Uninstall dependent interceptors first
        for (Class<WCInterceptor> dependentClass in dependentInterceptors) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                        category:@"Interception"
                                            file:__FILE__
                                            line:__LINE__
                                        function:__PRETTY_FUNCTION__
                                          format:@"Uninstalling dependent interceptor %@ before %@",
                                                 [dependentClass interceptorName],
                                                 [interceptorClass interceptorName]];

            if (![self uninstallInterceptor:dependentClass]) {
                [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                            category:@"Interception"
                                                file:__FILE__
                                                line:__LINE__
                                            function:__PRETTY_FUNCTION__
                                              format:@"Failed to uninstall dependent interceptor %@",
                                                     [dependentClass interceptorName]];
                return NO;
            }
        }
    }

    // Uninstall the interceptor
    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Uninstalling interceptor: %@",
                                          [interceptorClass interceptorName]];

    BOOL success = [interceptorClass uninstall];

    if (success) {
        [self.installedInterceptors removeObject:interceptorClass];
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Successfully uninstalled interceptor: %@",
                                              [interceptorClass interceptorName]];
    } else {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Failed to uninstall interceptor: %@",
                                              [interceptorClass interceptorName]];
    }

    return success;
}

#pragma mark - Status Checks

- (BOOL)isInterceptorInstalled:(Class<WCInterceptor>)interceptorClass {
    if (!interceptorClass) {
        return NO;
    }

    if ([self.installedInterceptors containsObject:interceptorClass]) {
        return [interceptorClass isInstalled];
    }

    return NO;
}

#pragma mark - Interceptor Queries

- (NSArray<Class<WCInterceptor>> *)allRegisteredInterceptors {
    return [self.registeredInterceptors copy];
}

- (NSArray<Class<WCInterceptor>> *)allInstalledInterceptors {
    return [self.installedInterceptors copy];
}

- (Class<WCInterceptor>)interceptorClassForName:(NSString *)name {
    if (!name) {
        return nil;
    }

    for (Class<WCInterceptor> interceptorClass in self.registeredInterceptors) {
        if ([[interceptorClass interceptorName] isEqualToString:name]) {
            return interceptorClass;
        }
    }

    return nil;
}

#pragma mark - Option Mapping

- (WCInterceptorOptions)optionForInterceptor:(Class<WCInterceptor>)interceptorClass {
    if (!interceptorClass) {
        return WCInterceptorOptionNone;
    }

    NSString *className = NSStringFromClass(interceptorClass);
    NSNumber *optionNumber = self.interceptorToOptionMap[className];

    if (optionNumber) {
        return [optionNumber unsignedIntegerValue];
    }

    return WCInterceptorOptionNone;
}

- (void)mapInterceptor:(Class<WCInterceptor>)interceptorClass toOption:(WCInterceptorOptions)option {
    if (!interceptorClass) {
        return;
    }

    NSString *className = NSStringFromClass(interceptorClass);
    self.interceptorToOptionMap[className] = @(option);

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelDebug
                                 category:@"Interception"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Mapped interceptor %@ to option %lu",
                                          [interceptorClass interceptorName],
                                          (unsigned long)option];
}

#pragma mark - Helper Methods

// Sort registered interceptors by priority (higher priority first)
- (void)sortRegisteredInterceptorsByPriority {
    [self.registeredInterceptors sortUsingComparator:^NSComparisonResult(id<WCInterceptor> class1, id<WCInterceptor> class2) {
        NSInteger priority1 = 0;
        NSInteger priority2 = 0;

        if ([class1 respondsToSelector:@selector(priority)]) {
            priority1 = [class1 priority];
        }

        if ([class2 respondsToSelector:@selector(priority)]) {
            priority2 = [class2 priority];
        }

        if (priority1 > priority2) {
            return NSOrderedAscending;
        } else if (priority1 < priority2) {
            return NSOrderedDescending;
        }

        return NSOrderedSame;
    }];
}

// Sort interceptors for installation, considering dependencies and priority
- (NSMutableArray<Class<WCInterceptor>> *)sortInterceptorsForInstallation {
    return [self sortInterceptorsForInstallation:self.registeredInterceptors];
}

- (NSMutableArray<Class<WCInterceptor>> *)sortInterceptorsForInstallation:(NSArray<Class<WCInterceptor>> *)interceptors {
    // Create a directed graph of dependencies
    NSMutableDictionary<NSString *, NSMutableArray *> *dependencyGraph = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *priorityMap = [NSMutableDictionary dictionary];

    // Initialize graph with all interceptors
    for (Class<WCInterceptor> interceptorClass in interceptors) {
        NSString *className = NSStringFromClass(interceptorClass);
        dependencyGraph[className] = [NSMutableArray array];

        NSInteger priority = 0;
        if ([interceptorClass respondsToSelector:@selector(priority)]) {
            priority = [interceptorClass priority];
        }
        priorityMap[className] = @(priority);
    }

    // Build dependency edges
    for (Class<WCInterceptor> interceptorClass in interceptors) {
        if ([interceptorClass respondsToSelector:@selector(dependencies)]) {
            NSArray<Class> *dependencies = [interceptorClass dependencies];
            NSString *className = NSStringFromClass(interceptorClass);

            for (Class dependencyClass in dependencies) {
                if ([interceptors containsObject:dependencyClass]) {
                    NSString *dependencyName = NSStringFromClass(dependencyClass);
                    [dependencyGraph[className] addObject:dependencyName];
                }
            }
        }
    }

    // Perform a topological sort with priority tiebreaking
    NSMutableArray<Class<WCInterceptor>> *result = [NSMutableArray array];
    NSMutableSet<NSString *> *visited = [NSMutableSet set];
    NSMutableSet<NSString *> *tempMarks = [NSMutableSet set];

    // Visit all nodes
    for (Class<WCInterceptor> interceptorClass in interceptors) {
        NSString *className = NSStringFromClass(interceptorClass);
        if (![visited containsObject:className]) {
            [self topologicalVisit:className
                           visited:visited
                         tempMarks:tempMarks
                  dependencyGraph:dependencyGraph
                       priorityMap:priorityMap
                           result:result
                       interceptors:interceptors];
        }
    }

    return result;
}

// Helper for topological sort
- (void)topologicalVisit:(NSString *)className
                 visited:(NSMutableSet *)visited
               tempMarks:(NSMutableSet *)tempMarks
         dependencyGraph:(NSDictionary *)dependencyGraph
             priorityMap:(NSDictionary *)priorityMap
                 result:(NSMutableArray *)result
            interceptors:(NSArray *)interceptors {

    // Check for circular dependency
    if ([tempMarks containsObject:className]) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelWarning
                                     category:@"Interception"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Circular dependency detected involving %@",
                                              className];
        return;
    }

    if (![visited containsObject:className]) {
        [tempMarks addObject:className];

        // Visit all dependencies first
        NSArray *dependencies = dependencyGraph[className];

        // Sort dependencies by priority (higher priority first)
        NSArray *sortedDependencies = [dependencies sortedArrayUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2) {
            NSInteger priority1 = [priorityMap[name1] integerValue];
            NSInteger priority2 = [priorityMap[name2] integerValue];

            if (priority1 > priority2) {
                return NSOrderedAscending;
            } else if (priority1 < priority2) {
                return NSOrderedDescending;
            }

            return NSOrderedSame;
        }];

        for (NSString *dependencyName in sortedDependencies) {
            [self topologicalVisit:dependencyName
                          visited:visited
                        tempMarks:tempMarks
                 dependencyGraph:dependencyGraph
                      priorityMap:priorityMap
                          result:result
                      interceptors:interceptors];
        }

        [tempMarks removeObject:className];
        [visited addObject:className];

        // Add class to result
        for (Class<WCInterceptor> interceptorClass in interceptors) {
            if ([NSStringFromClass(interceptorClass) isEqualToString:className]) {
                [result addObject:interceptorClass];
                break;
            }
        }
    }
}

// Find all interceptors that depend on a given interceptor
- (NSArray<Class<WCInterceptor>> *)interceptorsDependingOn:(Class<WCInterceptor>)interceptorClass {
    NSMutableArray<Class<WCInterceptor>> *dependentInterceptors = [NSMutableArray array];

    for (Class<WCInterceptor> potentialDependentClass in self.installedInterceptors) {
        if ([potentialDependentClass respondsToSelector:@selector(dependencies)]) {
            NSArray<Class> *dependencies = [potentialDependentClass dependencies];

            if ([dependencies containsObject:interceptorClass]) {
                [dependentInterceptors addObject:potentialDependentClass];
            }
        }
    }

    return dependentInterceptors;
}

@end
