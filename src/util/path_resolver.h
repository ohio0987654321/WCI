/**
 * @file path_resolver.h
 * @brief Centralized path resolution for WindowControlInjector
 *
 * This file defines a dedicated path resolver to centralize and improve
 * all path resolution logic throughout the application.
 */

#ifndef PATH_RESOLVER_H
#define PATH_RESOLVER_H

#import <Foundation/Foundation.h>

/**
 * @brief Dedicated path resolver for WindowControlInjector
 *
 * This class centralizes all path resolution logic, providing a clean API
 * for resolving and managing paths within the application.
 */
@interface WCPathResolver : NSObject

/**
 * @brief Get the shared path resolver instance
 *
 * @return The shared path resolver instance
 */
+ (instancetype)sharedResolver;

/**
 * @brief Resolve the path to the dylib
 *
 * This method searches for the dylib in known locations and returns the
 * full path if found.
 *
 * @return The path to the dylib, or nil if not found
 */
- (NSString *)resolvePathForDylib;

/**
 * @brief Resolve the executable path for an application
 *
 * This method finds the main executable within an application bundle.
 *
 * @param applicationPath Path to the application bundle
 * @return Path to the executable, or nil if not found
 */
- (NSString *)resolveExecutablePathForApplication:(NSString *)applicationPath;

/**
 * @brief Set a custom path for the dylib
 *
 * This method allows setting a custom path for the dylib instead of
 * searching for it.
 *
 * @param path The custom path to use
 */
- (void)setCustomDylibPath:(NSString *)path;

/**
 * @brief Get the currently set custom dylib path
 *
 * @return The custom dylib path, or nil if none is set
 */
- (NSString *)customDylibPath;

/**
 * @brief Get all search paths for the dylib
 *
 * @return An array of paths that are searched for the dylib
 */
- (NSArray<NSString *> *)searchPaths;

/**
 * @brief Add a search path for the dylib
 *
 * @param path The path to add to the search paths
 */
- (void)addSearchPath:(NSString *)path;

/**
 * @brief Remove a search path
 *
 * @param path The path to remove from the search paths
 * @return YES if the path was removed, NO if it wasn't found
 */
- (BOOL)removeSearchPath:(NSString *)path;

/**
 * @brief Clear all search paths
 */
- (void)clearSearchPaths;

/**
 * @brief Add standard search paths
 *
 * This method adds the standard search paths for the dylib based on
 * common locations and the current execution environment.
 */
- (void)addStandardSearchPaths;

/**
 * @brief Get the path to the log file
 *
 * @return The path to the log file
 */
- (NSString *)logFilePath;

/**
 * @brief Set the path to the log file
 *
 * @param path The path to use for the log file
 */
- (void)setLogFilePath:(NSString *)path;

/**
 * @brief Get the home directory path
 *
 * @return The home directory path
 */
- (NSString *)homeDirectoryPath;

/**
 * @brief Get the current working directory path
 *
 * @return The current working directory path
 */
- (NSString *)currentWorkingDirectoryPath;

/**
 * @brief Get the application support directory path
 *
 * @return The application support directory path
 */
- (NSString *)applicationSupportDirectoryPath;

/**
 * @brief Get the temporary directory path
 *
 * @return The temporary directory path
 */
- (NSString *)temporaryDirectoryPath;

/**
 * @brief Check if a file exists at the specified path
 *
 * @param path The path to check
 * @return YES if the file exists, NO otherwise
 */
- (BOOL)fileExistsAtPath:(NSString *)path;

/**
 * @brief Check if a directory exists at the specified path
 *
 * @param path The path to check
 * @return YES if the directory exists, NO otherwise
 */
- (BOOL)directoryExistsAtPath:(NSString *)path;

/**
 * @brief Create a directory at the specified path
 *
 * @param path The path where the directory should be created
 * @param createIntermediates YES to create intermediate directories, NO otherwise
 * @param error On output, if an error occurs, a pointer to an error object
 * @return YES if the directory was created successfully, NO otherwise
 */
- (BOOL)createDirectoryAtPath:(NSString *)path
      createIntermediates:(BOOL)createIntermediates
                    error:(NSError **)error;

@end

#endif /* PATH_RESOLVER_H */
