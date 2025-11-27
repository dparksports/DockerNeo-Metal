import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var dockView: DockView!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("1. applicationDidFinishLaunching started")
        
        // Create window
        let screen = NSScreen.main!
        let windowRect = NSRect(
            x: 0,
            y: 0,
            width: screen.frame.width,
            height: 120
        )
        
        print("2. Creating window...")
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        print("3. Window created")
        
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        print("4. Window configured")
        
        // Create dock view
        print("5. Creating DockView...")
        dockView = DockView()
        print("6. DockView created, calling setup...")
        dockView.setup()
        print("7. Setup complete, setting frame...")
        dockView.frame = window.contentView!.bounds
        dockView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(dockView)
        print("8. DockView added to window")
        
        // Load dock items
        print("9. Fetching dock items...")
        let items = IconManager.fetchDockItems()
        print("10. Got \(items.count) items, updating view...")
        dockView.updateItems(with: items)
        print("11. Items updated")
        
        print("12. Making window key and ordering front...")
        window.makeKeyAndOrderFront(nil)
        print("13. Activating app...")
        NSApp.activate(ignoringOtherApps: true)
        print("14. applicationDidFinishLaunching complete!")
    }
}
