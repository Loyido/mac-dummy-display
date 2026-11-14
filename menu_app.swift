import Cocoa
import CoreGraphics
import CoreVideo

// Disable buffering to flush stdout immediately for log capture
setbuf(stdout, nil)

private typealias DisplaySize = (width: UInt32, height: UInt32)

private struct DisplayProfile {
    let name: String
    let logicalSize: DisplaySize
    let backingSize: DisplaySize
    let refreshRates: [Double]
}

private struct DisplayPreset {
    let profileName: String
    let logicalSize: DisplaySize
    let backingSize: DisplaySize
    let refreshRates: [Double]

    init(profile: DisplayProfile) {
        self.profileName = profile.name
        self.logicalSize = profile.logicalSize
        self.backingSize = profile.backingSize
        self.refreshRates = profile.refreshRates
    }

    var menuTitle: String {
        "\(profileName) - \(logicalSize.width)x\(logicalSize.height)"
    }

    func statusTitle(refreshRate: Double?) -> String {
        if let refreshRate {
            return "\(profileName) \(logicalSize.width)x\(logicalSize.height) @\(Int(refreshRate))Hz"
        }

        return "\(profileName) \(logicalSize.width)x\(logicalSize.height)"
    }
}

private let defaultRefreshRates: [Double] = [60.0, 90.0, 120.0]

private let authorDefaultResolutions: [DisplaySize] = [
    (1440, 900),
    (1680, 1050),
    (1920, 1200),
    (2560, 1600),
    (2880, 1800),
    (3360, 2100),
    (3840, 2400),
    (5120, 3200)
]

private let customDisplayProfiles: [DisplayProfile] = [
    DisplayProfile(
        name: "MacBook Pro 14 Safe Area",
        logicalSize: (1512, 945),
        backingSize: (3024, 1890),
        refreshRates: [60.0, 120.0]
    ),
    DisplayProfile(
        name: "1080p 16:9",
        logicalSize: (1920, 1080),
        backingSize: (3840, 2160),
        refreshRates: [60.0, 120.0]
    ),
    DisplayProfile(
        name: "iPad mini 6",
        logicalSize: (1133, 744),
        backingSize: (2266, 1488),
        refreshRates: [60.0]
    ),
    DisplayProfile(
        name: "iPad Pro 11",
        logicalSize: (1210, 834),
        backingSize: (2420, 1668),
        refreshRates: [60.0, 120.0]
    ),
    DisplayProfile(
        name: "iPhone Duo Inner Display",
        logicalSize: (1335, 939),
        backingSize: (2670, 1878),
        refreshRates: [60.0, 120.0]
    )
]

private let customDisplayPresets: [DisplayPreset] = customDisplayProfiles.map { profile in
    DisplayPreset(profile: profile)
}

private func makeVirtualDisplayModes() -> [CGVirtualDisplayMode] {
    var modes: [CGVirtualDisplayMode] = []
    var seenModes = Set<String>()

    func appendMode(size: DisplaySize, refreshRate: Double) {
        let key = "\(size.width)x\(size.height)@\(Int(refreshRate * 1000))"
        guard !seenModes.contains(key) else { return }

        modes.append(CGVirtualDisplayMode(width: size.width, height: size.height, refreshRate: refreshRate))
        seenModes.insert(key)
    }

    for resolution in authorDefaultResolutions {
        for refreshRate in defaultRefreshRates {
            appendMode(size: resolution, refreshRate: refreshRate)
        }
    }

    for profile in customDisplayProfiles {
        print("Adding profile: \(profile.name) logical \(profile.logicalSize.width)x\(profile.logicalSize.height), backing \(profile.backingSize.width)x\(profile.backingSize.height)")
        for refreshRate in profile.refreshRates {
            appendMode(size: profile.logicalSize, refreshRate: refreshRate)
            appendMode(size: profile.backingSize, refreshRate: refreshRate)
        }
    }

    return modes
}

class DummyDisplayApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var virtualDisplay: CGVirtualDisplay?
    var displayLink: CVDisplayLink?
    var statusTimer: Timer?
    
    // Menu items
    var toggleItem: NSMenuItem!
    var statusItemMenu: NSMenuItem!
    var devicePresetMenuItem: NSMenuItem!
    var devicePresetMenuItems: [NSMenuItem] = []
    var refreshRateMenuItem: NSMenuItem!
    var refreshRateMenuItems: [NSMenuItem] = []
    
    var toggleSunshineItem: NSMenuItem!
    var statusSunshineMenu: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Dummy Display")
            } else {
                button.title = "🖥️"
            }
        }
        
        // Dynamically generate the LaunchAgent plist for the current user
        ensureLaunchAgentExists()
        
        setupMenu()
        
        // Start a timer to monitor Sunshine status every 1.5 seconds
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateSunshineMenuStatus()
            self?.updateDisplayMenuSelection()
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Virtual Display Section
        statusItemMenu = NSMenuItem(title: "Display: Inactive", action: nil, keyEquivalent: "")
        statusItemMenu.isEnabled = false
        menu.addItem(statusItemMenu)
        
        toggleItem = NSMenuItem(title: "Enable Virtual Display", action: #selector(toggleDisplay), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let devicePresetMenu = NSMenu(title: "Device Presets")
        devicePresetMenuItems = customDisplayPresets.enumerated().map { index, preset in
            let item = NSMenuItem(title: preset.menuTitle, action: #selector(selectDisplayPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.isEnabled = false
            devicePresetMenu.addItem(item)
            return item
        }

        devicePresetMenuItem = NSMenuItem(title: "Device Presets", action: nil, keyEquivalent: "")
        devicePresetMenuItem.submenu = devicePresetMenu
        devicePresetMenuItem.isEnabled = false
        menu.addItem(devicePresetMenuItem)

        let refreshRateMenu = NSMenu(title: "Refresh Rate")
        refreshRateMenuItems = defaultRefreshRates.enumerated().map { index, refreshRate in
            let item = NSMenuItem(title: "\(Int(refreshRate))Hz", action: #selector(selectRefreshRate(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.isEnabled = false
            refreshRateMenu.addItem(item)
            return item
        }

        refreshRateMenuItem = NSMenuItem(title: "Refresh Rate", action: nil, keyEquivalent: "")
        refreshRateMenuItem.submenu = refreshRateMenu
        refreshRateMenuItem.isEnabled = false
        menu.addItem(refreshRateMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Sunshine Section
        statusSunshineMenu = NSMenuItem(title: "Sunshine: Stopped", action: nil, keyEquivalent: "")
        statusSunshineMenu.isEnabled = false
        menu.addItem(statusSunshineMenu)
        
        toggleSunshineItem = NSMenuItem(title: "Start Sunshine", action: #selector(toggleSunshine), keyEquivalent: "s")
        toggleSunshineItem.target = self
        menu.addItem(toggleSunshineItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func toggleDisplay() {
        if virtualDisplay == nil {
            startDisplay()
        } else {
            stopDisplay()
        }
    }
    
    @objc func toggleSunshine() {
        if isSunshineRunning() {
            stopSunshine()
        } else {
            startSunshine()
        }
    }

    @objc private func selectDisplayPreset(_ sender: NSMenuItem) {
        guard customDisplayPresets.indices.contains(sender.tag) else { return }
        applyDisplayPreset(customDisplayPresets[sender.tag])
    }

    @objc private func selectRefreshRate(_ sender: NSMenuItem) {
        guard defaultRefreshRates.indices.contains(sender.tag) else { return }
        applyRefreshRate(defaultRefreshRates[sender.tag])
    }
    
    func startDisplay() {
        print("Initializing virtual display descriptor...")
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.name = "Dummy Retina Display"
        
        descriptor.maxPixelsWide = 5120
        descriptor.maxPixelsHigh = 3200
        
        descriptor.vendorID = 0xABCD
        descriptor.productID = 0x1234
        descriptor.serialNum = 42
        
        descriptor.sizeInMillimeters = CGSize(width: 340, height: 212)
        descriptor.queue = DispatchQueue.main
        
        descriptor.terminationHandler = { display in
            print("Virtual display termination handler triggered.")
        }
        
        let display = CGVirtualDisplay(descriptor: descriptor)
        virtualDisplay = display
        let displayID = display.displayID
        print("Virtual display created with Display ID: \(displayID)")
        
        // CGVirtualDisplayMode uses backing pixels. With hiDPI enabled, macOS exposes
        // the matching 2x logical sizes in System Settings.
        let modes = makeVirtualDisplayModes()
        print("Configured \(modes.count) virtual display modes.")
        
        let settings = CGVirtualDisplaySettings()
        settings.modes = modes
        settings.hiDPI = 1
        
        if display.apply(settings) {
            startDisplayLink(displayID: displayID)
            toggleItem.title = "Disable Virtual Display"
            statusItemMenu.title = "Display: Active (ID: \(displayID))"
            updateDisplayMenuState(isEnabled: true)
            updateDisplayMenuSelection()
            print("Display settings applied successfully. Display ID: \(displayID)")
            
            // Automatically update Sunshine configuration file with new Display ID
            updateSunshineConfig(displayID: displayID)
            
            // If Sunshine is already running, restart it to apply the new display ID
            if isSunshineRunning() {
                print("Sunshine is running. Restarting to apply new Display ID...")
                stopSunshine()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.startSunshine()
                }
            }
        } else {
            virtualDisplay = nil
            print("Failed to apply virtual display settings.")
        }
    }
    
    func stopDisplay() {
        stopDisplayLink()
        virtualDisplay = nil
        toggleItem.title = "Enable Virtual Display"
        statusItemMenu.title = "Display: Inactive"
        updateDisplayMenuState(isEnabled: false)
        print("Display stopped.")
    }

    private func updateDisplayMenuState(isEnabled: Bool) {
        devicePresetMenuItem?.isEnabled = isEnabled
        refreshRateMenuItem?.isEnabled = isEnabled

        for item in devicePresetMenuItems + refreshRateMenuItems {
            item.isEnabled = isEnabled
            item.state = .off
        }
    }

    private func applyDisplayPreset(_ preset: DisplayPreset) {
        guard let display = virtualDisplay else {
            statusItemMenu.title = "Display: Inactive"
            updateDisplayMenuState(isEnabled: false)
            return
        }

        let displayID = display.displayID
        let currentRefreshRate = currentDisplayRefreshRate(displayID: displayID)
        guard let mode = findDisplayMode(displayID: displayID, preset: preset, preferredRefreshRate: currentRefreshRate) else {
            statusItemMenu.title = "Preset missing: \(preset.profileName)"
            print("Could not find mode for preset: \(preset.menuTitle)")
            return
        }

        applyMode(mode, displayID: displayID, successMessage: "Applied preset: \(preset.menuTitle)", failureTitle: "Preset failed: \(preset.profileName)")
    }

    private func applyRefreshRate(_ refreshRate: Double) {
        guard let display = virtualDisplay else {
            statusItemMenu.title = "Display: Inactive"
            updateDisplayMenuState(isEnabled: false)
            return
        }

        let displayID = display.displayID
        guard let currentMode = CGDisplayCopyDisplayMode(displayID),
              let mode = findDisplayMode(displayID: displayID, size: displaySize(for: currentMode), refreshRate: refreshRate) else {
            statusItemMenu.title = "Refresh unavailable: \(Int(refreshRate))Hz"
            print("Could not find current-size mode at \(Int(refreshRate))Hz")
            return
        }

        applyMode(mode, displayID: displayID, successMessage: "Applied refresh rate: \(Int(refreshRate))Hz", failureTitle: "Refresh failed: \(Int(refreshRate))Hz")
    }

    private func applyMode(_ mode: CGDisplayMode, displayID: CGDirectDisplayID, successMessage: String, failureTitle: String) {
        let error = CGDisplaySetDisplayMode(displayID, mode, nil)
        if error == .success {
            print(successMessage)
            restartDisplayLink(displayID: displayID)
            updateDisplayMenuSelection()
        } else {
            statusItemMenu.title = failureTitle
            print("\(failureTitle). CGError: \(error.rawValue)")
        }
    }

    private func findDisplayMode(displayID: CGDirectDisplayID, preset: DisplayPreset, preferredRefreshRate: Double?) -> CGDisplayMode? {
        let refreshRates = orderedRefreshRates(preferred: preferredRefreshRate, available: preset.refreshRates)

        for refreshRate in refreshRates {
            if let mode = findDisplayMode(displayID: displayID, size: preset.logicalSize, refreshRate: refreshRate) {
                return mode
            }

            if let mode = findDisplayMode(displayID: displayID, size: preset.backingSize, refreshRate: refreshRate) {
                return mode
            }
        }

        return nil
    }

    private func findDisplayMode(displayID: CGDirectDisplayID, size: DisplaySize, refreshRate: Double) -> CGDisplayMode? {
        guard let modes = allDisplayModes(displayID: displayID) else {
            return nil
        }

        return modes.first { mode in
            modeMatches(mode, size: size, refreshRate: refreshRate)
        }
    }

    private func allDisplayModes(displayID: CGDirectDisplayID) -> [CGDisplayMode]? {
        let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
        return CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode]
    }

    private func updateDisplayMenuSelection() {
        guard let display = virtualDisplay else {
            updateDisplayMenuState(isEnabled: false)
            return
        }

        let displayID = display.displayID
        guard let currentMode = CGDisplayCopyDisplayMode(displayID) else { return }

        let currentRefreshRate = normalizedRefreshRate(currentMode.refreshRate)
        var matchedPreset: DisplayPreset?

        for (index, preset) in customDisplayPresets.enumerated() {
            let isMatch = modeSizeMatches(currentMode, size: preset.logicalSize) ||
                modeSizeMatches(currentMode, size: preset.backingSize)

            devicePresetMenuItems[index].state = isMatch ? .on : .off
            if isMatch {
                matchedPreset = preset
            }
        }

        for (index, refreshRate) in defaultRefreshRates.enumerated() {
            let hasCurrentSizeMode = findDisplayMode(displayID: displayID, size: displaySize(for: currentMode), refreshRate: refreshRate) != nil
            refreshRateMenuItems[index].isEnabled = hasCurrentSizeMode
            refreshRateMenuItems[index].state = currentRefreshRate.map { abs($0 - refreshRate) < 0.5 } == true ? .on : .off
        }

        if let preset = matchedPreset {
            statusItemMenu.title = "Display: \(preset.statusTitle(refreshRate: currentRefreshRate))"
        } else {
            let size = displaySize(for: currentMode)
            if let currentRefreshRate {
                statusItemMenu.title = "Display: \(size.width)x\(size.height) @\(Int(currentRefreshRate))Hz"
            } else {
                statusItemMenu.title = "Display: \(size.width)x\(size.height)"
            }
        }
    }

    private func orderedRefreshRates(preferred: Double?, available: [Double]) -> [Double] {
        var orderedRates: [Double] = []

        if let preferred, available.contains(where: { abs($0 - preferred) < 0.5 }) {
            orderedRates.append(preferred)
        }

        orderedRates.append(contentsOf: available.sorted(by: >).filter { rate in
            !orderedRates.contains(where: { abs($0 - rate) < 0.5 })
        })

        return orderedRates
    }

    private func currentDisplayRefreshRate(displayID: CGDirectDisplayID) -> Double? {
        guard let currentMode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        return normalizedRefreshRate(currentMode.refreshRate)
    }

    private func normalizedRefreshRate(_ refreshRate: Double) -> Double? {
        refreshRate > 0 ? refreshRate : nil
    }

    private func displaySize(for mode: CGDisplayMode) -> DisplaySize {
        (UInt32(mode.width), UInt32(mode.height))
    }

    private func modeMatches(_ mode: CGDisplayMode, size: DisplaySize, refreshRate: Double) -> Bool {
        let modeRefreshRate = mode.refreshRate
        let refreshMatches = modeRefreshRate == 0 || abs(modeRefreshRate - refreshRate) < 0.5

        return modeSizeMatches(mode, size: size) && refreshMatches
    }

    private func modeSizeMatches(_ mode: CGDisplayMode, size: DisplaySize) -> Bool {
        UInt32(mode.width) == size.width && UInt32(mode.height) == size.height
    }

    private func restartDisplayLink(displayID: CGDirectDisplayID) {
        stopDisplayLink()
        startDisplayLink(displayID: displayID)
    }
    
    func startDisplayLink(displayID: CGDirectDisplayID) {
        var link: CVDisplayLink?
        let result = CVDisplayLinkCreateWithCGDisplay(displayID, &link)
        
        guard result == kCVReturnSuccess, let activeLink = link else {
            print("Warning: Failed to create CVDisplayLink.")
            return
        }
        
        let status = CVDisplayLinkSetOutputCallback(activeLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            return kCVReturnSuccess
        }, nil)
        
        if status == kCVReturnSuccess {
            CVDisplayLinkStart(activeLink)
            displayLink = activeLink
            print("CVDisplayLink started for Display ID: \(displayID)")
        } else {
            print("Warning: Failed to set CVDisplayLink output callback.")
        }
    }
    
    func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
            print("CVDisplayLink stopped.")
        }
    }
    
    func getSunshineConfigPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/sunshine/sunshine.conf").path
    }
    
    func getLaunchAgentPlistPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent("Library/LaunchAgents/com.patrikviktor.sunshine.plist").path
    }
    
    func ensureLaunchAgentExists() {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let launchAgentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistPath = getLaunchAgentPlistPath()
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.patrikviktor.sunshine</string>
            <key>ProgramArguments</key>
            <array>
                <string>/opt/homebrew/bin/sunshine</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(homeDir.path)/.config/sunshine/sunshine_launch.log</string>
            <key>StandardErrorPath</key>
            <string>\(homeDir.path)/.config/sunshine/sunshine_launch.log</string>
        </dict>
        </plist>
        """
        
        do {
            try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            print("LaunchAgent plist verified/written at: \(plistPath)")
        } catch {
            print("Failed to write LaunchAgent plist: \(error)")
        }
    }
    
    func updateSunshineConfig(displayID: CGDirectDisplayID) {
        let fileManager = FileManager.default
        let configPath = getSunshineConfigPath()
        
        do {
            var configContent = ""
            if fileManager.fileExists(atPath: configPath) {
                configContent = try String(contentsOfFile: configPath, encoding: .utf8)
            }
            
            let lines = configContent.components(separatedBy: .newlines)
            var newLines: [String] = []
            var outputNameFound = false
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("output_name") {
                    newLines.append("output_name = \(displayID)")
                    outputNameFound = true
                } else {
                    newLines.append(line)
                }
            }
            
            if !outputNameFound {
                newLines.append("output_name = \(displayID)")
            }
            
            let newContent = newLines.joined(separator: "\n")
            try newContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("Updated sunshine.conf with output_name = \(displayID)")
        } catch {
            print("Error updating sunshine.conf: \(error)")
        }
    }
    
    func isSunshineRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "sunshine"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    func updateSunshineMenuStatus() {
        let running = isSunshineRunning()
        if running {
            toggleSunshineItem.title = "Stop Sunshine"
            statusSunshineMenu.title = "Sunshine: Running"
        } else {
            toggleSunshineItem.title = "Start Sunshine"
            statusSunshineMenu.title = "Sunshine: Stopped"
        }
    }
    
    func startSunshine() {
        guard !isSunshineRunning() else { return }
        
        // Decouple Sunshine from DummyDisplay's process tree and TCC permissions context
        // by launching it via macOS launchd (launchctl load) with the dynamically generated plist.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", getLaunchAgentPlistPath()]
        
        do {
            try process.run()
            process.waitUntilExit()
            print("Sunshine started via launchctl load.")
            
            // Give it a brief moment to start and let the UI update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.updateSunshineMenuStatus()
            }
        } catch {
            print("Failed to start Sunshine via launchctl: \(error)")
        }
    }
    
    func stopSunshine() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", getLaunchAgentPlistPath()]
        
        do {
            try process.run()
            process.waitUntilExit()
            print("Sunshine stopped via launchctl unload.")
            
            // Just in case, kill any lingering processes
            let killProcess = Process()
            killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProcess.arguments = ["sunshine"]
            try? killProcess.run()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.updateSunshineMenuStatus()
            }
        } catch {
            print("Failed to stop Sunshine via launchctl: \(error)")
        }
    }
    
    @objc func quit() {
        stopDisplay()
        stopSunshine()
        statusTimer?.invalidate()
        NSApplication.shared.terminate(self)
    }
}

// Application Entry Point
let app = NSApplication.shared
let delegate = DummyDisplayApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
