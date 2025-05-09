# WindowControlInjector Debugging Guide

This document contains guidance for debugging common issues with the WindowControlInjector library.

## Interceptor Installation Issues

If the library loads successfully (as shown in wci_debug.log) but isn't modifying application behavior, check the following:

### 1. Interceptor Installation

The most common issue is that interceptors aren't being installed correctly, even though the dylib is loading. The key indicators are:

- "WindowControlInjector dylib loaded" appears in the log
- Profile application is successful
- But the target application doesn't exhibit the expected behavior changes

**Solution:** Ensure that `WCInitialize()` is calling the install methods for both interceptors:

```objective-c
// In src/core/injector.m - WCInitialize() function
BOOL windowSuccess = [WCNSWindowInterceptor install];
BOOL appSuccess = [WCNSApplicationInterceptor install];
```

### 2. Method Swizzling Sequence

A subtle but critical issue with method swizzling is the sequence of operations:

1. First, add the new methods to the target class
2. Then swizzle them with the original methods

**Incorrect approach:**
```objective-c
// DO NOT do this - it creates a conflict
// First swizzle methods
WCSwizzleMethod(nsWindowClass, @selector(sharingType), @selector(wc_sharingType));
// Then try to add methods that are already modified
class_addMethod(nsWindowClass, @selector(wc_sharingType), (IMP)wc_sharingType, "Q@:");
```

**Correct approach:**
```objective-c
// First register the new methods
WCAddMethod(nsWindowClass, @selector(wc_sharingType), (IMP)wc_sharingType, "Q@:");
// Then swizzle with the original methods
WCSwizzleMethod(nsWindowClass, @selector(sharingType), @selector(wc_sharingType));
```

### 3. Debugging with Enhanced Logging

To debug interceptor issues:

1. Add detailed logging in the `+install` methods
2. Log the success/failure of each swizzle operation
3. Check the interceptor installation status in the debug log

## Common Profile Issues

If interceptors are installed but profiles aren't working:

1. Verify profile property names match the interceptor property names exactly
2. Ensure property types are compatible (e.g., NSNumber for BOOL values)
3. Check that the profile is correctly registered in `WCProfileManager`

## Testing Changes

After making changes:

1. Rebuild the project: `make clean && make`
2. Test with a simple application: `./build/injector --invisible /Applications/Calculator.app`
3. Check the wci_debug.log file for detailed diagnostic information
