import Foundation
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
        name: "MacBook Pro 14 Retina",
        logicalSize: (1512, 982),
        backingSize: (3024, 1964),
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
    )
]

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
            appendMode(size: profile.backingSize, refreshRate: refreshRate)
        }
    }

    return modes
}

// Global references to keep the virtual display and display link alive
var virtualDisplay: CGVirtualDisplay?
var displayLink: CVDisplayLink?

func startDisplayLink(displayID: CGDirectDisplayID) {
    print("Setting up CVDisplayLink to prevent frame drops...")
    var link: CVDisplayLink?
    let result = CVDisplayLinkCreateWithCGDisplay(displayID, &link)
    
    guard result == kCVReturnSuccess, let activeLink = link else {
        print("Warning: Failed to create CVDisplayLink.")
        return
    }
    
    // Set a C-compatible no-op callback. This callback is triggered by the window server
    // at the display's refresh rate (60Hz), forcing constant VSync rendering on this headless display.
    let status = CVDisplayLinkSetOutputCallback(activeLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
        return kCVReturnSuccess
    }, nil)
    
    if status == kCVReturnSuccess {
        CVDisplayLinkStart(activeLink)
        displayLink = activeLink
        print("CVDisplayLink successfully started for Display ID: \(displayID)")
        print("Displej je teraz chránený pred sekaním (Frame Throttling) zo strany macOS.")
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

func createVirtualDisplay() {
    print("Initializing virtual display descriptor...")
    let descriptor = CGVirtualDisplayDescriptor()
    descriptor.name = "Dummy Retina Display"
    
    // Set maximum resolution bounds to support our maximum backing store size (5120x3200)
    descriptor.maxPixelsWide = 5120
    descriptor.maxPixelsHigh = 3200
    
    descriptor.vendorID = 0xABCD
    descriptor.productID = 0x1234
    descriptor.serialNum = 42 // Constant to ensure stable Display ID in Sunshine
    
    descriptor.sizeInMillimeters = CGSize(width: 340, height: 212)
    descriptor.queue = DispatchQueue.main
    
    descriptor.terminationHandler = { display in
        print("Virtual display termination handler triggered.")
    }
    
    print("Instantiating CGVirtualDisplay...")
    let display = CGVirtualDisplay(descriptor: descriptor)
    virtualDisplay = display
    
    let displayID = display.displayID
    print("Virtual display created with Display ID: \(displayID)")
    
    print("Configuring display modes...")
    // CGVirtualDisplayMode uses backing pixels. With hiDPI enabled, macOS exposes
    // the matching 2x logical sizes in System Settings.
    let modes = makeVirtualDisplayModes()
    print("Configured \(modes.count) virtual display modes.")
    
    let settings = CGVirtualDisplaySettings()
    settings.modes = modes
    settings.hiDPI = 1 // Enable Retina scaling
    
    print("Applying settings...")
    if display.apply(settings) {
        print("Successfully applied settings to virtual display.")
        print("Displej je teraz aktívny s HiDPI škálovaním na frekvencii 60Hz.")
        print("Môžete si vybrať menšie Retina rozlíšenia v: System Settings -> Displays")
        
        // Start the display link to lock the window server frame updates to 60Hz
        startDisplayLink(displayID: displayID)
    } else {
        print("Error: Failed to apply settings.")
        virtualDisplay = nil
        exit(1)
    }
}

func setupSignalHandlers() {
    // Register standard C signal handlers. C-convention closures can access global variables/functions.
    signal(SIGINT) { _ in
        print("\nPrerušenie prijaté (SIGINT). Odstraňujem displej...")
        stopDisplayLink()
        virtualDisplay = nil
        exit(0)
    }

    signal(SIGTERM) { _ in
        print("\nUkončenie prijaté (SIGTERM). Odstraňujem displej...")
        stopDisplayLink()
        virtualDisplay = nil
        exit(0)
    }
}

// Main execution
setupSignalHandlers()
createVirtualDisplay()

print("Spúšťam RunLoop. Pre ukončenie stlačte Ctrl+C...")
RunLoop.main.run()
