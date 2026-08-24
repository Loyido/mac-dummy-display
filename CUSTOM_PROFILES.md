# Custom Retina Profiles Worklog

## Baseline

- Upstream repository: `https://github.com/patrikviktor/mac-dummy-display.git`
- Clean upstream commit: `4d0b80a6eae93b6c900f9bdb064a32f5fb7c715d`
- Working branch: `retina-device-profiles`
- Local backup: `/Users/no1801-hometheater/Documents/mac-dummy-display-backup-20260824-170410`

The existing `/Users/no1801-hometheater/Documents/mac-dummy-display` checkout was already clean and matched `origin/main`. The user's `Documents` directory has an ACL that denies directory delete/rename operations, so the old checkout was copied with `ditto` instead of being renamed or deleted.

## Source Changes

- Added `build_app.sh` for repeatable app bundle creation and ad-hoc signing.
- Kept the author's original resolution list:
  - `1440x900`
  - `1680x1050`
  - `1920x1200`
  - `2560x1600`
  - `2880x1800`
  - `3360x2100`
  - `3840x2400`
  - `5120x3200`
- Kept the author's original default refresh rates: `60Hz`, `90Hz`, `120Hz`.
- Added named custom profile data to both `menu_app.swift` and `main.swift`.
- Added duplicate-mode filtering so overlapping width/height/refresh combinations are registered once.
- Register each custom profile's logical size and 2x backing size as a pair, matching the author's original HiDPI mode pattern.
- Added Menu Bar quick switching:
  - `Device Presets` switches by named device profile and preserves the current refresh rate when possible.
  - `Refresh Rate` switches the current size to an available discrete refresh mode.
  - `CVDisplayLink` is restarted after a successful mode switch so frame pacing follows the active mode.

## Added HiDPI Profiles

| Profile | Logical size | Backing pixels | Refresh rates |
| --- | ---: | ---: | --- |
| MacBook Pro 14 Retina | `1512x982` | `3024x1964` | `60Hz`, `120Hz` |
| MacBook Pro 14 Safe Area | `1512x945` | `3024x1890` | `60Hz`, `120Hz` |
| 1080p 16:9 | `1920x1080` | `3840x2160` | `60Hz`, `120Hz` |
| iPad mini 6 | `1133x744` | `2266x1488` | `60Hz` |
| iPad Pro 11 | `1210x834` | `2420x1668` | `60Hz`, `120Hz` |

The logical and backing entries are both registered because macOS Display Settings exposes HiDPI choices more consistently when it can see the 1x logical size and the 2x backing size as a pair, such as `1133x744` and `2266x1488` for iPad mini 6.

`MacBook Pro 14 Retina` targets the full 3024x1964 panel. `MacBook Pro 14 Safe Area` targets the area below the camera housing, which is useful when a full-screen streaming client avoids the notch region and otherwise shows side bars.

## Build Commands

Preferred:

```bash
./build_app.sh
```

Manual equivalent:

```bash
mkdir -p DummyDisplay.app/Contents/MacOS
cp Info.plist DummyDisplay.app/Contents/
swiftc menu_app.swift \
  -import-objc-header DummyDisplay-Bridging-Header.h \
  -framework CoreGraphics \
  -framework Foundation \
  -framework CoreVideo \
  -framework AppKit \
  -o DummyDisplay.app/Contents/MacOS/dummy_display_menu
codesign --force --deep --sign - DummyDisplay.app
```

CLI compile check:

```bash
swiftc main.swift \
  -import-objc-header DummyDisplay-Bridging-Header.h \
  -framework CoreGraphics \
  -framework Foundation \
  -framework CoreVideo \
  -o /private/tmp/dummy_display_cli
```

## Verification Results

- `./build_app.sh` completed successfully.
- `swiftc main.swift ...` completed successfully.
- `codesign --verify --deep --strict --verbose=2 DummyDisplay.app` passed.
- Build warnings are limited to the pre-existing macOS 15+ `CVDisplayLink` deprecation warnings.
- Sunshine is installed at `/opt/homebrew/bin/sunshine`, pointing to `sunshine-beta/2026.619.155209`.
- Sunshine config exists at `/Users/no1801-hometheater/.config/sunshine/sunshine.conf`.
- Current Sunshine config includes `output_name = 10`.
- Sunshine log already verifies the iPad mini 6 HiDPI path:
  - display name: `Ipad mini 6 Virtual Display`
  - logical mode: `1133x744 points`
  - backing mode: `2266x1488 pixels`
  - refresh rate: `60 Hz`
  - encoder: `hevc_videotoolbox`
  - client connection reached `CLIENT CONNECTED`
- Parsec is installed at `/Applications/Parsec.app` and was visible as a running app through Codex's UI app list.
- VS Code was visible as a running app, with the `mac-dummy-display` workspace open.

## Chain Check Notes

- DummyDisplay is running as `com.patrikviktor.DummyDisplay` in the user's launchd GUI session.
- Current Sunshine config has `output_name = 10`, matching the active DummyDisplay ID seen in Sunshine logs.
- Sunshine log verifies `Dummy Retina Display` at `1133x744 points`, `2266x1488 pixels`, `60 Hz`, selected for AVFoundation capture.
- Sunshine version checked locally: `2026.619.155209`, publisher `LizardByte`.
- Sunshine uses `encoder = videotoolbox`, `port = 47980`, and exposes the configuration UI on `47981`.
- Parsec is installed at `/Applications/Parsec.app`, version `150.95.1`, and is visible in the user's launchd GUI session.
- Moonlight is installed at `/Applications/Moonlight.app`, version `6.1.0`, and has an existing saved host preference. It was not visible as a running app during this check.
- The current chain supports discrete refresh modes, not continuous ProMotion-style variable refresh. For best pacing, match the virtual display refresh rate to the client stream frame rate.
- The built app in `/Users/no1801-hometheater/Documents/mac-dummy-display/DummyDisplay.app` is newer than `/Applications/DummyDisplay.app`. The `/Applications` copy could not be overwritten from the Codex sandbox.

## Pitfalls

- The Codex terminal cannot rename the existing checkout because `/Users/no1801-hometheater/Documents` has `group:everyone deny delete`; copying the backup is safer.
- `code` is not installed in `PATH`, although Visual Studio Code itself is installed and running.
- The Codex terminal could not use `pgrep` or `ps` because process-list access is blocked by the current environment.
- LaunchServices `open` reported `kLSNoExecutableErr` for generated app bundles and even for `/Applications/Visual Studio Code.app` from this sandbox, so Finder/VS Code/user-session launch should be used for final manual app launch confirmation.
- Running the CLI utility from the Codex terminal reached `CGVirtualDisplay` creation but failed at `apply(settings)` for both the original upstream CLI and the modified CLI. This appears to be a terminal/session limitation rather than a custom-profile regression.
- Writing to `/Applications` was not granted in this run; the signed `DummyDisplay.app` is built in the project directory and can be copied manually if needed.
