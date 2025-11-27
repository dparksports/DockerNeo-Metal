import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: FloatingWindow!
    var heightMapView: HeightMapView!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the window
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 200
        let windowRect = NSRect(
            x: (screenRect.width - windowWidth) / 2,
            y: (screenRect.height - windowHeight) / 2,
            width: windowWidth,
            height: windowHeight
        )
        
        window = FloatingWindow(contentRect: windowRect)
        
        // Create HeightMapView
        heightMapView = HeightMapView(frame: window.contentView!.bounds)
        heightMapView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(heightMapView)
        
        // Load Content
        loadContent()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func loadContent() {
        // 1. Try to capture Dock info
        if let (dockImage, dockFrame) = DockCapturer.captureDock() {
            print("Dock found. Frame: \(dockFrame)")
            
            // Position window over the Dock
            if let screen = NSScreen.main {
                let screenHeight = screen.frame.height
                // Convert CGWindow coordinates (Top-Left) to NSWindow coordinates (Bottom-Left)
                let newY = screenHeight - dockFrame.origin.y - dockFrame.height
                let newFrame = NSRect(x: dockFrame.origin.x, y: newY, width: dockFrame.width, height: dockFrame.height)
                
                window.setFrame(newFrame, display: true)
            }
            
            if let image = dockImage {
                print("Dock image captured.")
                heightMapView.update(with: image)
            } else {
                print("Dock image missing (permission denied). Using running apps.")
                let items = IconManager.fetchDockItems()
                heightMapView.update(with: items)
            }
        } else {
            // 2. Fallback if Dock not found
            print("Dock not found. Using default position at bottom of screen.")
            if let screen = NSScreen.main {
                let width: CGFloat = 800
                let height: CGFloat = 150
                let x = (screen.frame.width - width) / 2
                let y: CGFloat = 20 // 20px from bottom
                let frame = NSRect(x: x, y: y, width: width, height: height)
                window.setFrame(frame, display: true)
            }
            
            let items = IconManager.fetchDockItems()
            heightMapView.update(with: items)
        }
    }
}
