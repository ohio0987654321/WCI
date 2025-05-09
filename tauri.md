# Screen Recording and Capture Prevention Techniques Using Window Properties

This document provides a comprehensive list of window property-based techniques that can be used to prevent screen recording and capture. These techniques are primarily focused on system-level properties rather than CSS-based visual tricks.

## Core Protection Properties

### Content Protection
```rust
// Tauri API
window.set_content_protected(true)

// macOS Native
let _: () = msg_send![ns_window, setSharingType: 0]; // NSWindowSharingNone
```
This setting explicitly marks the window content as protected, which instructs the operating system to block capture attempts. When enabled, most screen recording software will show a black rectangle instead of the actual window content.

### Window Level Control
```rust
// macOS constant
const NS_FLOATING_WINDOW_LEVEL: i32 = 3;

// macOS Implementation
let _: () = msg_send![ns_window, setLevel: NS_FLOATING_WINDOW_LEVEL];

// Tauri Alternative
window.set_always_on_top(true)
```
Setting a window to a special level (like floating window level) can interfere with some capture software that relies on standard window z-ordering.

### Exclusion from Window Lists
```rust
// macOS Implementation
let _: () = msg_send![ns_window, setExcludedFromWindowsMenu: YES];

// Tauri Alternative
window.set_skip_taskbar(true)
```
This prevents the window from appearing in window lists, making it harder for capture software to identify and target the window.

## Window Collection Behavior (macOS)

```rust
// Constants
pub const NS_WINDOW_COLLECTION_BEHAVIOR_STATIONARY: u64 = 1 << 0;
pub const NS_WINDOW_COLLECTION_BEHAVIOR_IGNORES_CYCLE: u64 = 1 << 3;
const NS_WINDOW_COLLECTION_BEHAVIOR_FULL_SCREEN_PRIMARY: u64 = 1 << 7;
const NS_WINDOW_COLLECTION_BEHAVIOR_FULL_SCREEN_AUXILIARY: u64 = 1 << 8;
pub const NS_WINDOW_COLLECTION_BEHAVIOR_CAN_JOIN_ALL_SPACES: u64 = 1 << 16;

// Implementation
let collection_behavior: u64 =
    NS_WINDOW_COLLECTION_BEHAVIOR_STATIONARY |
    NS_WINDOW_COLLECTION_BEHAVIOR_FULL_SCREEN_PRIMARY |
    NS_WINDOW_COLLECTION_BEHAVIOR_IGNORES_CYCLE |
    NS_WINDOW_COLLECTION_BEHAVIOR_CAN_JOIN_ALL_SPACES |
    NS_WINDOW_COLLECTION_BEHAVIOR_FULL_SCREEN_AUXILIARY;

let _: () = msg_send![ns_window, setCollectionBehavior: collection_behavior];
```
These collection behavior flags control how the window interacts with macOS window management features like Mission Control and Spaces. The combination of these flags makes the window behave in special ways that can confuse capture software.

## Mission Control and System UI Integration Prevention

```rust
// Hide from Mission Control
let _: () = msg_send![ns_window, setCanHide: NO];

// Remove from standard window cycle
let _: () = msg_send![ns_window, setCollectionBehavior: NS_WINDOW_COLLECTION_BEHAVIOR_IGNORES_CYCLE];
```
These settings prevent the window from appearing in Mission Control and exclude it from standard window cycling (Alt+Tab), making it harder to target with capture software.

## Window Decorations and UI Element Hiding

```rust
// Hide window buttons (close, minimize, maximize)
let close_button: id = msg_send![ns_window, standardWindowButton:0]; // NSWindowCloseButton
if !close_button.is_null() {
    let _: () = msg_send![close_button, setHidden:YES];
}

let minimize_button: id = msg_send![ns_window, standardWindowButton:1]; // NSWindowMiniaturizeButton
if !minimize_button.is_null() {
    let _: () = msg_send![minimize_button, setHidden:YES];
}

let zoom_button: id = msg_send![ns_window, standardWindowButton:2]; // NSWindowZoomButton
if !zoom_button.is_null() {
    let _: () = msg_send![zoom_button, setHidden:YES];
}

// Hide window decorations
window.set_decorations(false)

// Make titlebar transparent
let _: () = msg_send![ns_window, setTitlebarAppearsTransparent: YES];
```
Removing standard window decorations and controls makes it harder to identify the application window and can interfere with some capture techniques.

## Transparency and Shadow Manipulation

```rust
// Remove window shadows
let _: () = msg_send![ns_window, setHasShadow: NO];

// Make window non-opaque
let _: () = msg_send![ns_window, setOpaque: NO];

// Set window background to transparent
let ns_color_class = objc::runtime::Class::get("NSColor").unwrap();
let clear_color: id = msg_send![ns_color_class, clearColor];
let _: () = msg_send![ns_window, setBackgroundColor: clear_color];

// Control alpha value
let _: () = msg_send![ns_window, setAlphaValue: 0.8];
```
Manipulating window transparency and shadows can interfere with certain capture techniques that rely on window bounds detection.

## Window Display and Movement Behavior

```rust
// Make window movable by background
let _: () = msg_send![ns_window, setMovableByWindowBackground: YES];

// Use dark appearance to interfere with contrast-based capture
let appearance_class = class!(NSAppearance);
let appearance_name = "NSAppearanceNameVibrantDark";
let ns_string = NSString::alloc(nil).init_str(appearance_name);
let appearance: id = msg_send![appearance_class, appearanceNamed: ns_string];
let _: () = msg_send![ns_window, setAppearance: appearance];
```
Special movement behaviors and appearance settings can further complicate capture attempts.

## Dock Icon and Status Bar Management (macOS)

```rust
// Verify activation policy to keep dock icon hidden
wizid_infra::macos::verify_activation_policy()

// Ensure hidden from dock
wizid_infra::macos::ensure_hidden_from_dock(window)

// Re-initialize status bar to ensure consistency
wizid_infra::macos::ensure_status_bar_initialized(window)
```
Preventing the application from showing in the dock and properly managing the status bar makes it harder to identify and target with capture software. The status bar initialization ensures that the application maintains a consistent presence in the status bar while remaining hidden from other UI elements.

## Window Show/Hide Multi-Step Sequence

```rust
// Multi-step window showing sequence
window.set_content_protected(true)
window.set_decorations(false)
window.set_always_on_top(true)
window.set_skip_taskbar(true)
window.hide()
thread::sleep(Duration::from_millis(15))
window.show()
thread::sleep(Duration::from_millis(15))
window.unminimize()
thread::sleep(Duration::from_millis(15))
window.maximize()
```
Using complex sequences with precise timing for window operations can confuse capture software that relies on standard window state transitions.

## Main Thread Execution

```rust
pub fn run_on_main_thread<F, R: Runtime>(app_handle: &AppHandle<R>, f: F) -> Result<()>
where
    F: FnOnce() -> Result<()> + Send + 'static
{
    app_handle.run_on_main_thread(move || {
        if let Err(e) = f() {
            eprintln!("Error in main thread operation: {}", e);
        }
    })
}
```
Ensuring all window operations run on the main thread provides more reliable and precisely timed window manipulations, which is crucial for effective capture prevention.

---

**Note**: The effectiveness of these techniques can vary by operating system, capture software, and implementation details. For maximum protection, it's recommended to combine multiple techniques rather than relying on a single approach.
