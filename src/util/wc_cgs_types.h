/**
 * @file wc_cgs_types.h
 * @brief Core Graphics Services (CGS) API types for WindowControlInjector
 *
 * This file defines the necessary types and function pointer types for
 * working with the undocumented Core Graphics Services (CGS) API.
 * These types enable universal window control across all application types.
 */

#ifndef WC_CGS_TYPES_H
#define WC_CGS_TYPES_H

#include <CoreGraphics/CoreGraphics.h>

// Connection types
typedef uint32_t CGSConnectionID;

// Window types
typedef uint32_t CGSWindowID;

// Window sharing types (mirroring NSWindowSharingType values)
typedef enum {
    CGSWindowSharingNone = 0,
    CGSWindowSharingReadOnly = 1,
    CGSWindowSharingReadWrite = 2
} CGSWindowSharingType;

// Function pointer types
typedef CGSConnectionID (*CGSDefaultConnectionPtr)(void);
typedef CGError (*CGSSetWindowSharingStatePtr)(CGSConnectionID cid, CGSWindowID wid, CGSWindowSharingType sharing);
typedef CGError (*CGSGetWindowSharingStatePtr)(CGSConnectionID cid, CGSWindowID wid, CGSWindowSharingType *sharing);
typedef CGError (*CGSSetWindowLevelPtr)(CGSConnectionID cid, CGSWindowID wid, CGWindowLevel level);
typedef CGError (*CGSGetWindowLevelPtr)(CGSConnectionID cid, CGSWindowID wid, CGWindowLevel *level);

#endif /* WC_CGS_TYPES_H */
