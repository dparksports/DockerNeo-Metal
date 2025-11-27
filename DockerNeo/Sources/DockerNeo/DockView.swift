import Cocoa
import Metal
import QuartzCore

class DockView: NSView {
    var renderer: DockRenderer?
    private var displayLink: CVDisplayLink?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CAMetalLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    func setup() {
        print("DockView.setup() called")
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Failed to create Metal device!")
            return
        }
        
        print("Metal device created: \(device.name)")
        
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = false
        
        print("Creating renderer...")
        renderer = DockRenderer(view: self, device: device)
        print("Renderer created")
        print("DockView.setup() complete")
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        renderer?.mouseX = location.x
        renderer?.render()
    }
    
    override func mouseExited(with event: NSEvent) {
        renderer?.mouseX = nil
        renderer?.render()
    }
    
    func updateItems(with items: [DockItem]) {
        renderer?.update(with: items)
        renderer?.render()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = CGSize(width: newSize.width * 2, height: newSize.height * 2)
        renderer?.viewportSize = newSize
    }
}
