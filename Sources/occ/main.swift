import AppKit
import OCCKit

// OpenCrashCart — macOS app. Runs as a regular windowed app from a plain SwiftPM executable
// (no .app bundle needed for development; we bundle + sign for distribution later).

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let controller = AppController()
app.delegate = controller

// The full menu bar is built by AppController in applicationDidFinishLaunching.
app.activate(ignoringOtherApps: true)
app.run()
