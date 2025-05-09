# WindowControlInjector Debugging Guide

This guide helps you understand how to effectively use WindowControlInjector, particularly the new direct-control profile, and how to troubleshoot common issues.

## Using the Direct Control Profile

The direct-control profile offers enhanced window control capabilities by using direct Objective-C messaging rather than property interception. This provides more robust protection against screen recording and better UI element hiding.

### Basic Usage

The simplest way to use the direct-control profile is with our convenience script:

```bash
./direct_launch.sh /Applications/YourApp.app
```

This script will:
1. Build the injector if necessary
2. Apply the direct-control profile to your application
3. Launch the application with verbose logging

For manual usage with the injector binary:

```bash
./build/injector --direct-control --verbose /Applications/YourApp.app
```

### Direct Control vs. Traditional Profiles

| Feature | Traditional Approach | Direct Control Approach |
|---------|---------------------|------------------------|
| Method | Property interception | Active window management |
| How it works | Swizzles getters/setters | Direct window control + notifications |
| Screen recording protection | Basic (NSWindowSharingNone) | Enhanced (multiple techniques) |
| Focus control | Property-based | Dynamic class creation |
| Update frequency | One-time | Continuous monitoring |

## Debugging Common Issues

### Issue: App Crashes on Launch

**Possible causes:**
- Missing entitlements
- Architecture mismatch
- Version incompatibility

**Solutions:**
1. Verify the app is compatible with your macOS version
2. Check the console logs:
   ```bash
   tail -f /var/log/system.log
   ```
3. Try with verbose logging:
   ```bash
   ./build/injector --direct-control --verbose --debug /Applications/YourApp.app
   ```

### Issue: Windows Still Visible in Recordings

**Possible causes:**
- Advanced screen recording software
- Partial implementation
- App using custom window types

**Solutions:**
1. Use the direct-control profile which has enhanced protection:
   ```bash
   ./direct_launch.sh /Applications/YourApp.app
   ```
2. Check the application's window hierarchy:
   ```objc
   po [[NSApplication sharedApplication] windows]
   ```
3. Try combining profiles:
   ```bash
   ./build/injector --invisible --direct-control /Applications/YourApp.app
   ```

### Issue: App Still Appears in Dock

**Possible causes:**
- App using non-standard activation policies
- Multiple windows or processes

**Solutions:**
1. Combine stealth with direct-control:
   ```bash
   ./build/injector --stealth --direct-control /Applications/YourApp.app
   ```
2. Check the application's activation policy:
   ```bash
   ./build/injector --debug /Applications/YourApp.app
   ```

### Issue: Mouse Events Not Working as Expected

**Possible causes:**
- Conflicting window settings
- Custom event handling in the app

**Solutions:**
1. Try different profile combinations:
   ```bash
   ./build/injector --click-through --unfocusable /Applications/YourApp.app
   ```
   vs.
   ```bash
   ./build/injector --direct-control /Applications/YourApp.app
   ```
2. Debug window event handling:
   ```bash
   ./build/injector --verbose --debug /Applications/YourApp.app
   ```

## Advanced Usage

### Executable Resolution

When an application doesn't follow standard macOS app bundle structure, you might need to help the injector find the executable. The `--debug` flag provides detailed information about executable path resolution:

```bash
./build/injector --debug /Path/To/NonStandard.app
```

This will show:
- Attempted paths
- Resolving symlinks
- Bundle structure analysis
- Executable detection steps

### Custom Property Overrides

For advanced users, you can directly override specific properties:

```objc
NSWindow.level=1000
NSWindow.ignoresMouseEvents=YES
NSApplication.activationPolicy=1
```

### Performance Considerations

- **Memory Usage**: Direct-control uses periodic timers and notification observers that can increase memory usage slightly
- **CPU Usage**: The continuous monitoring approach uses negligible CPU (less than 0.1%)
- **Launch Time**: There might be a slight delay (milliseconds) in initial launch due to the dynamic subclassing

## Troubleshooting Core Issues

### Library Loading Problems

If the dylib fails to load:

1. Check permissions:
   ```bash
   chmod +x ./build/injector
   chmod +x ./direct_launch.sh
   ```

2. Verify code signing:
   ```bash
   codesign -vv build/lib/libwindow_control.dylib
   ```

3. Check for SIP (System Integrity Protection) conflicts:
   ```bash
   csrutil status
   ```

### Debugging Using Console App

Open Console.app and filter for "WindowControlInjector" to see detailed logs:

1. With verbose logging enabled, you'll see:
   - Window creation events
   - Property changes
   - Notification registrations
   - Dynamic class creation

2. Look for warnings and errors that might indicate issues.

## Internal Architecture

### Direct Control Implementation

The direct-control profile uses multiple techniques:

1. **Dynamic Class Creation**:
   - Creates custom window subclasses at runtime
   - Overrides methods like `canBecomeKey` and `canBecomeMain`
   - Preserves other behaviors

2. **Notification Observers**:
   - Listens for `NSWindowDidExposeNotification`
   - Automatically applies settings to new windows

3. **Periodic Timers**:
   - Reapplies settings every second
   - Ensures consistent behavior even if the app changes settings

4. **Direct Property Access**:
   - Uses setValue:forKey: for better compatibility
   - Handles properties not accessible through normal APIs

## Contributing and Extending

To add new capabilities or fix issues:

1. Study the profiles in `profiles/` directory
2. Understand the interceptors in `src/interceptors/`
3. Consider how to extend the direct control capabilities in `src/core/direct_window_control.m`

The modular architecture makes it easy to add new features without affecting existing functionality.
