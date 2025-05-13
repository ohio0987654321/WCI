/**
 * @file wc_process_manager.m
 * @brief Implementation of process management utilities
 */

#import "wc_process_manager.h"
#import "../util/logger.h"
#import <AppKit/AppKit.h>

@implementation WCProcessManager

#pragma mark - Process Management

+ (NSArray<NSNumber *> *)getChildProcessesForPID:(pid_t)pid {
    NSMutableArray<NSNumber *> *childPIDs = [NSMutableArray array];

    // Use ps command to get child processes
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/ps"];
    [task setArguments:@[@"-eo", @"ppid,pid"]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    NSFileHandle *file = [pipe fileHandleForReading];

    @try {
        [task launch];
        [task waitUntilExit];

        if ([task terminationStatus] != 0) {
            [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                         category:@"ProcessManager"
                                             file:__FILE__
                                             line:__LINE__
                                         function:__PRETTY_FUNCTION__
                                           format:@"Failed to get child processes for PID: %d", (int)pid];
            return @[];
        }

        NSData *data = [file readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        // Parse the output - format is:
        // PPID  PID
        // ...
        NSArray<NSString *> *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        for (NSString *line in lines) {
            // Skip header line
            if ([line hasPrefix:@"PPID"] || [line length] == 0) {
                continue;
            }

            NSArray<NSString *> *parts = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];

            if (parts.count >= 2) {
                NSInteger ppid = [parts[0] integerValue];

                if (ppid == pid) {
                    NSInteger childPID = [parts[1] integerValue];
                    [childPIDs addObject:@(childPID)];
                }
            }
        }
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"ProcessManager"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception while getting child processes: %@", exception.reason];
    }

    return [childPIDs copy];
}

+ (NSString *)getProcessNameForPID:(pid_t)pid {
    NSString *processName = @"";

    // Use ps command to get process name
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/ps"];
    [task setArguments:@[@"-p", [NSString stringWithFormat:@"%d", pid], @"-o", @"command="]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    NSFileHandle *file = [pipe fileHandleForReading];

    @try {
        [task launch];
        [task waitUntilExit];

        if ([task terminationStatus] == 0) {
            NSData *data = [file readDataToEndOfFile];
            processName = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            processName = [processName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
    } @catch (NSException *exception) {
        [[WCLogger sharedLogger] logWithLevel:WCLogLevelError
                                     category:@"ProcessManager"
                                         file:__FILE__
                                         line:__LINE__
                                     function:__PRETTY_FUNCTION__
                                       format:@"Exception while getting process name: %@", exception.reason];
    }

    return processName;
}

+ (NSArray<NSNumber *> *)getElectronRendererProcessesForMainPID:(pid_t)mainPID {
    NSMutableArray<NSNumber *> *rendererPIDs = [NSMutableArray array];
    NSArray<NSNumber *> *childPIDs = [self getChildProcessesForPID:mainPID];

    // First level of child processes from main Electron process
    for (NSNumber *childPID in childPIDs) {
        pid_t pid = [childPID intValue];

        // We need to check if this is a renderer process by checking process name
        NSString *processName = [self getProcessNameForPID:pid];

        // Electron renderer processes often have "Renderer" or "Helper" in their name
        if ([processName containsString:@"Renderer"] ||
            [processName containsString:@"Helper"] ||
            [processName containsString:@"electron"]) {
            [rendererPIDs addObject:childPID];

            // Also get any grandchild processes of detected renderer
            NSArray<NSNumber *> *grandchildPIDs = [self getChildProcessesForPID:pid];
            [rendererPIDs addObjectsFromArray:grandchildPIDs];
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"ProcessManager"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Found %lu Electron renderer processes for main PID: %d",
                                         (unsigned long)rendererPIDs.count, (int)mainPID];

    return [rendererPIDs copy];
}

+ (NSArray<NSNumber *> *)getChromeRendererProcessesForMainPID:(pid_t)mainPID {
    NSMutableArray<NSNumber *> *rendererPIDs = [NSMutableArray array];
    NSArray<NSNumber *> *childPIDs = [self getChildProcessesForPID:mainPID];

    // Chrome has a more complex process structure with multiple helpers
    for (NSNumber *childPID in childPIDs) {
        pid_t pid = [childPID intValue];

        // Check process name
        NSString *processName = [self getProcessNameForPID:pid];

        // Chrome renderer processes usually have "Helper" in their name
        if ([processName containsString:@"Helper"]) {
            [rendererPIDs addObject:childPID];

            // Add grandchildren - Chrome has multiple levels of helper processes
            NSArray<NSNumber *> *grandchildPIDs = [self getChildProcessesForPID:pid];
            [rendererPIDs addObjectsFromArray:grandchildPIDs];

            // Chrome can have even deeper process trees, so add great-grandchildren
            for (NSNumber *grandchildPID in grandchildPIDs) {
                NSArray<NSNumber *> *greatGrandchildPIDs = [self getChildProcessesForPID:[grandchildPID intValue]];
                [rendererPIDs addObjectsFromArray:greatGrandchildPIDs];
            }
        }
    }

    [[WCLogger sharedLogger] logWithLevel:WCLogLevelInfo
                                 category:@"ProcessManager"
                                     file:__FILE__
                                     line:__LINE__
                                 function:__PRETTY_FUNCTION__
                                   format:@"Found %lu Chrome renderer processes for main PID: %d",
                                         (unsigned long)rendererPIDs.count, (int)mainPID];

    return [rendererPIDs copy];
}

+ (NSString *)getApplicationPathForPID:(pid_t)pid {
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    return [[app bundleURL] path];
}

@end
