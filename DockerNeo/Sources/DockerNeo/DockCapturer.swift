import Cocoa
import CoreGraphics

class DockCapturer {
    static func captureDock() -> (image: NSImage?, frame: CGRect)? {
        // 1. Find the Dock window
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        // The Dock is usually owned by "Dock" process
        guard let dockWindowInfo = windowList.first(where: { 
            ($0[kCGWindowOwnerName as String] as? String) == "Dock" 
        }) else {
            return nil
        }
        
        guard let windowID = dockWindowInfo[kCGWindowNumber as String] as? CGWindowID else {
            return nil
        }
        
        // Get Frame
        var frame = CGRect.zero
        if let boundsDict = dockWindowInfo[kCGWindowBounds as String] as? [String: Any] {
            frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) ?? .zero
        }
        
        // 2. Capture the image
        // .boundsIgnoreFraming captures just the window content
        // Note: If permission is denied, this might return nil or a desktop image.
        // We will return whatever we get, but the frame is useful regardless.
        let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, .boundsIgnoreFraming)
        
        let image: NSImage?
        if let cgImage = cgImage {
             image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } else {
            image = nil
        }
        
        return (image, frame)
    }
}
