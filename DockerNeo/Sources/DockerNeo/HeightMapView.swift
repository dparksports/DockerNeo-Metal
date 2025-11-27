import Cocoa
import CoreImage
import CoreImage.CIFilterBuiltins

class HeightMapView: NSView {
    private var dockItems: [DockItem] = []
    private var processedIcons: [NSImage] = [] // Mapped 1:1 to dockItems
    private let context = CIContext()
    private var trackingArea: NSTrackingArea?
    private var mouseX: CGFloat?
    
    // Layout Constants
    private let baseSize: CGFloat = 64.0
    private let dividerWidth: CGFloat = 2.0 // Thin line
    private let dividerSpacing: CGFloat = 15.0 // Spacing around divider
    private let itemSpacing: CGFloat = 10.0
    
    private let maxMagnification: CGFloat = 1.5
    private let influenceRadius: CGFloat = 150.0
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(rect: bounds,
                                      options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
                                      owner: self,
                                      userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        var currentX = (bounds.width - calculateTotalWidth()) / 2.0
        let centerY = bounds.height / 2.0
        
        for (i, item) in dockItems.enumerated() {
            let isDivider: Bool
            if case .divider = item.type { isDivider = true } else { isDivider = false }
            let baseWidth = isDivider ? dividerWidth : baseSize
            let spacing = isDivider ? dividerSpacing : itemSpacing
            
            // Calculate scale (Dividers don't scale much, or maybe they do?)
            // Let's scale everything for consistency
            let baseCenterX = currentX + baseWidth / 2.0 // Approximation for hit testing
            
            var scale: CGFloat = 1.0
            if let mouseX = mouseX {
                // Calculate center based on "base" layout (simplified for hit test)
                // Ideally we'd need the exact center, but this is circular dependency.
                // Using the visual center is better.
                let distance = abs(mouseX - (currentX + baseWidth/2.0))
                if distance < influenceRadius {
                    let factor = (1 - distance / influenceRadius)
                    scale = 1.0 + (maxMagnification - 1.0) * (factor * factor)
                }
            }
            
            let width = baseWidth * scale
            let height = isDivider ? (baseSize * 0.8 * scale) : (baseSize * scale)
            
            let rect = NSRect(x: currentX, y: centerY - height / 2.0, width: width, height: height)
            
            if rect.contains(location) {
                handleItemClick(item)
                return
            }
            
            currentX += width + spacing
        }
    }
    
    private func handleItemClick(_ item: DockItem) {
        switch item.type {
        case .persistentApp(_, _, let url):
            if let url = url {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        case .runningApp(let app):
            app.activate(options: .activateIgnoringOtherApps)
        case .folder(let url, _):
            NSWorkspace.shared.open(url)
        case .trash:
            // Open Trash folder
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first!
            NSWorkspace.shared.open(trashURL)
        case .divider:
            break
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        mouseX = location.x
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseX = nil
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let image = contentImage {
            // Draw single image (Dock Screenshot)
            let aspectRatio = image.size.width / image.size.height
            let drawHeight = bounds.height * 0.8
            let drawWidth = drawHeight * aspectRatio
            let drawX = (bounds.width - drawWidth) / 2
            let drawY = (bounds.height - drawHeight) / 2
            let drawRect = NSRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
            
            drawBackpanel(in: drawRect.insetBy(dx: -10, dy: -10))
            if let processed = applyHeightMap(to: image) {
                processed.draw(in: drawRect)
            } else {
                image.draw(in: drawRect)
            }
            return
        }
        
        guard !dockItems.isEmpty else { return }
        
        let totalWidth = calculateTotalWidth()
        let startX = (bounds.width - totalWidth) / 2.0
        
        // Draw Backpanel
        // Make it tighter: Height based on baseSize, not maxMag? No, needs to fit mag.
        // User said "short height". Maybe less padding?
        // Let's use a fixed height that fits the magnified icons but with less vertical padding.
        
        let panelHeight = baseSize * maxMagnification + 4 // Very tight padding
        let panelRect = NSRect(x: startX - 10,
                               y: (bounds.height - panelHeight) / 2.0,
                               width: totalWidth + 20,
                               height: panelHeight)
        
        drawBackpanel(in: panelRect)
        
        // Draw Items
        var currentX = startX
        let centerY = bounds.height / 2.0
        
        for (i, item) in dockItems.enumerated() {
            let isDivider = item.type == .divider
            let baseWidth = isDivider ? dividerWidth : baseSize
            let spacing = isDivider ? dividerSpacing : itemSpacing
            
            // Calculate Scale
            // We need the "base" center for the magnification calculation to be stable
            // But for drawing, we just need the current visual position.
            // The "fisheye" effect relies on the mouse position relative to the icon's center.
            
            let itemCenter = currentX + baseWidth / 2.0 // This is the visual center
            // Note: Real Dock calculates scale based on "unmagnified" position.
            // Implementing that perfectly requires a two-pass layout.
            // Pass 1: Calculate unmagnified centers.
            // Pass 2: Calculate scales and positions.
            
            // Let's do the two-pass approach for stability
            
            // But for now, let's use the visual center approximation which works "okay" for simple effects,
            // or better: calculate the "base" center (unmagnified) for the scale factor.
            
            let baseCenter = calculateBaseCenter(at: i)
            var scale: CGFloat = 1.0
            
            if let mouseX = mouseX {
                let distance = abs(mouseX - (startX + baseCenter)) // Relative to startX
                if distance < influenceRadius {
                    let factor = (1 - distance / influenceRadius)
                    scale = 1.0 + (maxMagnification - 1.0) * (factor * factor)
                }
            }
            
            let width = baseWidth * scale
            let height = isDivider ? (baseSize * 0.8 * scale) : (baseSize * scale) // Dividers are shorter
            
            let rect = NSRect(x: currentX,
                              y: centerY - height / 2.0,
                              width: width,
                              height: height)
            
            if isDivider {
                drawDivider(in: rect)
            } else {
                if i < processedIcons.count {
                    processedIcons[i].draw(in: rect)
                }
            }
            
            currentX += width + spacing
        }
    }
    
    private func calculateBaseCenter(at index: Int) -> CGFloat {
        var x: CGFloat = 0
        for i in 0..<index {
            let item = dockItems[i]
            let isDivider: Bool
            if case .divider = item.type { isDivider = true } else { isDivider = false }
            
            let w = isDivider ? dividerWidth : baseSize
            let s = isDivider ? dividerSpacing : itemSpacing
            x += w + s
        }
        let currentItem = dockItems[index]
        let isCurrentDivider: Bool
        if case .divider = currentItem.type { isCurrentDivider = true } else { isCurrentDivider = false }
        
        let currentW = isCurrentDivider ? dividerWidth : baseSize
        return x + currentW / 2.0
    }
    
    private func calculateTotalWidth() -> CGFloat {
        var width: CGFloat = 0
        // We need to sum up the widths *with* magnification
        // This requires iterating and calculating scale for each
        
        // 1. Calculate Base Start X (needed for scale calc)
        // Actually, we can just sum up.
        
        let totalBaseWidth = calculateBaseWidth()
        let startXBase = (bounds.width - totalBaseWidth) / 2.0
        
        for (i, item) in dockItems.enumerated() {
            let isDivider = item.type == .divider
            let baseWidth = isDivider ? dividerWidth : baseSize
            let spacing = isDivider ? dividerSpacing : itemSpacing
            
            let baseCenter = calculateBaseCenter(at: i) // Offset from start
            let absoluteBaseCenter = startXBase + baseCenter
            
            var scale: CGFloat = 1.0
            if let mouseX = mouseX {
                let distance = abs(mouseX - absoluteBaseCenter)
                if distance < influenceRadius {
                    let factor = (1 - distance / influenceRadius)
                    scale = 1.0 + (maxMagnification - 1.0) * (factor * factor)
                }
            }
            
            width += baseWidth * scale
            // Add spacing (spacing doesn't scale in this simple model, but maybe it should?)
            // Let's keep spacing constant for now.
            if i < dockItems.count - 1 {
                width += spacing
            }
        }
        return width
    }
    
    private func calculateBaseWidth() -> CGFloat {
        var width: CGFloat = 0
        for (i, item) in dockItems.enumerated() {
            let isDivider: Bool
            if case .divider = item.type { isDivider = true } else { isDivider = false }
            
            width += isDivider ? dividerWidth : baseSize
            if i < dockItems.count - 1 {
                width += isDivider ? dividerSpacing : itemSpacing
            }
        }
        return width
    }
    
    func update(with items: [DockItem]) {
        self.contentImage = nil
        self.dockItems = items
        print("Processing \(items.count) icons...")
        // Process icons (skip dividers)
        self.processedIcons = items.map { item in
            if case .divider = item.type {
                return NSImage() // Placeholder
            }
            return applyHeightMap(to: item.icon) ?? item.icon
        }
        print("Processing complete.")
        self.needsDisplay = true
    }
    
    func update(with image: NSImage) {
        // Single image mode (Screenshot)
        self.dockItems = [] // Clear items
        self.processedIcons = []
        // We need to handle drawing this single image.
        // The current draw() assumes dockItems.
        // Let's add a separate property for single image or just wrap it?
        // Wrapping it in a DockItem is hard because it's one big image.
        // Let's add `private var contentImage: NSImage?` back.
        self.contentImage = image
        self.needsDisplay = true
    }
    private var contentImage: NSImage?
    
    private func drawBackpanel(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        let gradient = NSGradient(starting: NSColor(white: 0.2, alpha: 0.9), // Darker for "Docker" look
                                  ending: NSColor(white: 0.1, alpha: 0.9))
        gradient?.draw(in: path, angle: -90)
        
        NSColor(white: 1.0, alpha: 0.1).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
    
    private func drawDivider(in rect: NSRect) {
        // Draw a vertical line
        let path = NSBezierPath()
        // Center the line in the rect
        let x = rect.midX
        path.move(to: NSPoint(x: x, y: rect.minY))
        path.line(to: NSPoint(x: x, y: rect.maxY))
        path.lineWidth = 1.5
        NSColor(white: 0.3, alpha: 1.0).setStroke() // Dark gray divider
        path.stroke()
    }
    
    private func applyHeightMap(to image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmap) else { return nil }
        
        // 0. Apply Grayscale
        let grayscaleFilter = CIFilter.photoEffectMono()
        grayscaleFilter.inputImage = ciImage
        guard let grayscaleImage = grayscaleFilter.outputImage else { return nil }
        
        guard let heightFieldFilter = CIFilter(name: "CIHeightFieldFromMask") else { return nil }
        heightFieldFilter.setValue(grayscaleImage, forKey: kCIInputImageKey)
        heightFieldFilter.setValue(5.0, forKey: "inputRadius")
        
        guard let heightField = heightFieldFilter.outputImage else { return nil }
        
        guard let shadedMaterialFilter = CIFilter(name: "CIShadedMaterial") else { return nil }
        shadedMaterialFilter.setValue(heightField, forKey: kCIInputImageKey)
        shadedMaterialFilter.setValue(grayscaleImage, forKey: "inputShadingImage")
        shadedMaterialFilter.setValue(5.0, forKey: "inputScale")
        
        guard let outputImage = shadedMaterialFilter.outputImage else { return nil }
        
        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
