# macOS Virtual Display & Sunshine Controller

Chinese documentation: [README.zh-CN.md](README.zh-CN.md)

A unified macOS Menu Bar application that creates a minimalist virtual display (dummy display) and manages LizardByte's Sunshine streaming server, optimized for low-latency, high-refresh-rate streaming to clients like Moonlight.

## Features

- **Virtual Display Creation**: Instantiates a virtual screen (up to 5120x3200) with proper Retina (HiDPI) scaling support and multiple refresh rates (**60Hz, 90Hz, and 120Hz**).
- **Custom Retina Device Profiles**: Adds paired logical and backing-pixel modes for MacBook Pro 14 Safe Area, 1080p 16:9, iPad mini 6, iPad Pro 11, and the unfolded iPhone Duo while keeping the original upstream resolution set.
- **Quick Switching Menus**: Adds Menu Bar submenus for named device presets and refresh-rate changes, so you do not need to remember each resolution number.
- **Frame Pacing (Anti-Throttling)**: Implements `CVDisplayLink` to force constant frame rendering on the headless display, bypassing macOS's aggressive window server frame throttling.
- **Detached Sunshine Execution**: Bypasses macOS Sequoia's screen recording permission loops. By running Sunshine as a detached `LaunchAgent`, permission is attributed directly to the `sunshine` binary (already approved) rather than the wrapper app.
- **Auto-Configuring LaunchAgent**: Automatically generates the required LaunchAgent plist configuration locally using the active user's home path on app launch. No manual file copying required.
- **Unified Menu Bar Control**: Start/stop the virtual display and Sunshine independently or exit both from a single dropdown icon (`🖥️`).
- **Wi-Fi Optimization Utility**: Includes a script to temporarily disable AWDL (`awdl0` interface) to resolve background AirDrop scanning packet drops.

---

## Project Structure

- `menu_app.swift`: The Swift source code for the Menu Bar GUI application.
- `main.swift`: CLI version of the virtual display utility.
- `build_app.sh`: Reproducible build script for the signed menu bar `.app` bundle.
- `DummyDisplay-Bridging-Header.h`: Exposes private CoreGraphics APIs (`CGVirtualDisplay`) to Swift.
- `toggle_awdl.sh`: Helper script to toggle AWDL down/up.
- `Info.plist`: Application package configuration.

---

## Custom Retina Profiles

The menu app and CLI keep the author's original modes and add these paired 1x logical and 2x HiDPI backing modes:

| Profile | Logical size shown by macOS | Backing pixels passed to `CGVirtualDisplayMode` | Refresh rates |
| --- | ---: | ---: | --- |
| MacBook Pro 14 Safe Area | 1512x945 | 3024x1890 | 60Hz, 120Hz |
| 1080p 16:9 | 1920x1080 | 3840x2160 | 60Hz, 120Hz |
| iPad mini 6 | 1133x744 | 2266x1488 | 60Hz |
| iPad Pro 11 | 1210x834 | 2420x1668 | 60Hz, 120Hz |
| iPhone Duo Inner Display | 1335x939 | 2670x1878 | 60Hz, 120Hz |

The iPhone Duo preset uses the full unfolded inner display in landscape (445:313). See [Apple's display specifications](https://www.apple.com/iphone-duo/specs/).

The logical and backing entries are both registered because macOS Display Settings exposes HiDPI choices more consistently when it can see the 1x logical size and the 2x backing size as a pair.

The Menu Bar app exposes quick switching through:

- `Device Presets`: switches the virtual display to a named logical resolution while preserving the current refresh rate when that rate exists for the selected profile.
- `Refresh Rate`: switches the current virtual display size to `60Hz`, `90Hz`, or `120Hz` when that mode exists.

This is discrete mode switching, not continuous ProMotion-style variable refresh. `CVDisplayLink` is restarted after a successful mode switch so frame pacing follows the new display mode.

For a 14-inch MacBook Pro client that keeps full-screen apps below the camera housing, use `MacBook Pro 14 Safe Area` to target the 1512x945 safe area and reduce side bars.

---

## Setup & Installation

### 1. Build the App Bundle

To package this as a standard macOS `.app` bundle:

```bash
./build_app.sh
```

Equivalent manual commands:

```bash
# Recreate the bundle directory structure
mkdir -p DummyDisplay.app/Contents/MacOS

# Copy Info.plist into the bundle
cp Info.plist DummyDisplay.app/Contents/

# Compile the binary
swiftc menu_app.swift \
  -import-objc-header DummyDisplay-Bridging-Header.h \
  -framework CoreGraphics -framework Foundation -framework CoreVideo -framework AppKit \
  -o DummyDisplay.app/Contents/MacOS/dummy_display_menu

# Sign the app locally to ensure stable macOS TCC registration
codesign --force --deep --sign - DummyDisplay.app
```

Move `DummyDisplay.app` to your `/Applications` directory.

### 2. Screen Recording Permissions

To allow Sunshine to capture the screen without permission prompts:
- Open **System Settings > Privacy & Security > Screen & System Audio Recording**.
- Click the `+` button and add the **real path** of the Sunshine binary (resolving the Homebrew symlink):
  `/opt/homebrew/Cellar/sunshine/<version>/bin/sunshine`
- Ensure it is checked/enabled.

---

## Usage

1. Launch **`DummyDisplay`** from your Applications folder.
2. Click the monitor icon `🖥️` in your macOS Menu Bar:
   - Click **Enable Virtual Display**.
   - Click **Start Sunshine**.
3. Connect your tablet/client device via **Moonlight** using the appropriate IP (e.g., `10.0.2.2` if tethered via USB and `gnirehtet` is running, or your Mac's network IP).
4. If your client supports high refresh rates (like 90Hz or 120Hz), select the desired refresh rate in Moonlight or macOS display preferences.

### Wi-Fi Latency Optimization
If you stream over Wi-Fi and experience periodic stuttering, disable background AirDrop scanning:
```bash
sudo ./toggle_awdl.sh down
```
To enable it back later:
```bash
sudo ./toggle_awdl.sh up
```

## License
MIT
