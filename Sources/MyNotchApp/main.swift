import AppKit
import NotchKit

// Top-level code runs on the main actor. `delegate` is global so it outlives app.run().
let app = NSApplication.shared
let delegate = NotchAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon; LSUIElement takes over once bundled (F5)
app.run()
