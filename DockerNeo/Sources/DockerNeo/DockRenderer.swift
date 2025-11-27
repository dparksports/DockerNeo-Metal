import Metal
import MetalKit
import simd
import CoreImage
import QuartzCore

struct Uniforms {
    var projectionMatrix: matrix_float4x4
    var modelMatrix: matrix_float4x4
}

class DockRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState!
    var samplerState: MTLSamplerState!
    
    weak var view: DockView?
    
    var dockItems: [DockItem] = []
    var textures: [MTLTexture?] = []
    var quadVertexBuffer: MTLBuffer!
    
    var mouseX: CGFloat?
    var viewportSize: CGSize = .zero
    
    // Layout constants
    let baseSize: CGFloat = 64
    let dividerWidth: CGFloat = 2
    let spacing: CGFloat = 10
    let maxMagnification: CGFloat = 1.5
    let influenceRadius: CGFloat = 150
    
    // Core Image for processing
    let ciContext = CIContext()
    
    init?(view: DockView, device: MTLDevice) {
        guard let queue = device.makeCommandQueue() else { return nil }
        
        self.device = device
        self.commandQueue = queue
        self.view = view
        self.viewportSize = view.bounds.size
        
        setupPipeline()
        setupBuffers()
    }
    
    func setupPipeline() {
        var library: MTLLibrary?
        
        do {
            if let url = Bundle.module.url(forResource: "default", withExtension: "metallib") {
                library = try device.makeLibrary(URL: url)
                print("✓ Loaded default.metallib")
            } else if let url = Bundle.module.url(forResource: "Shaders", withExtension: "metal") {
                let source = try String(contentsOf: url)
                library = try device.makeLibrary(source: source, options: nil)
                print("✓ Compiled Shaders.metal")
            } else {
                library = device.makeDefaultLibrary()
                print("✓ Loaded default library")
            }
        } catch {
            print("Failed to load library: \(error)")
            return
        }
        
        guard let library = library else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }
    
    func setupBuffers() {
        let vertices: [Float] = [
            0, 0,  0, 1,
            1, 0,  1, 1,
            0, 1,  0, 0,
            1, 1,  1, 0
        ]
        quadVertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * 4, options: [])
    }
    
    func update(with items: [DockItem]) {
        self.dockItems = items
        self.textures = items.map { item in
            createTexture(from: item.icon)
        }
    }
    
    func createTexture(from image: NSImage) -> MTLTexture? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        
        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(data: data, options: [.origin: MTKTextureLoader.Origin.bottomLeft])
    }
    
    
    func render() {
        print("render() called")
        
        guard let view = view else {
            print("ERROR: view is nil")
            return
        }
        print("render() - view OK")
        
        guard let metalLayer = view.layer as? CAMetalLayer else {
            print("ERROR: layer is not CAMetalLayer")
            return
        }
        print("render() - metalLayer OK")
        
        guard let drawable = metalLayer.nextDrawable() else {
            print("ERROR: nextDrawable() returned nil")
            return
        }
        print("render() - drawable OK")
        
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[0].storeAction = .store
        print("render() - descriptor OK")
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("ERROR: makeCommandBuffer() returned nil")
            return
        }
        print("render() - commandBuffer OK")
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            print("ERROR: makeRenderCommandEncoder() returned nil")
            return
        }
        print("render() - renderEncoder OK")
        
        guard let pipelineState = pipelineState else {
            print("ERROR: pipelineState is nil")
            return
        }
        print("render() - pipelineState OK")
        
        let width = Float(viewportSize.width)
        let height = Float(viewportSize.height)
        let projection = orthoMatrix(left: 0, right: width, bottom: 0, top: height, near: -1, far: 1)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        print("render() - drawing \(dockItems.count) items")
        
        // Calculate layout
        var currentX: CGFloat = (CGFloat(width) - totalWidth()) / 2
        
        for (i, item) in dockItems.enumerated() {
            let isDivider = (item.type == .divider)
            let w = isDivider ? dividerWidth : baseSize
            
            let centerX = currentX + w / 2
            let scale = calculateScale(centerX: centerX)
            let scaledW = w * scale
            let scaledH = (isDivider ? baseSize * 0.8 : baseSize) * scale
            
            if !isDivider, let texture = textures[i] {
                let model = modelMatrix(x: Float(currentX), y: Float((CGFloat(height) - scaledH) / 2),
                                       w: Float(scaledW), h: Float(scaledH))
                var uniforms = Uniforms(projectionMatrix: projection, modelMatrix: model)
                
                renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
                renderEncoder.setFragmentTexture(texture, index: 0)
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            
            currentX += scaledW + spacing
        }
        
        print("render() - ending encoding")
        renderEncoder.endEncoding()
        print("render() - presenting drawable")
        commandBuffer.present(drawable)
        print("render() - committing")
        commandBuffer.commit()
        print("render() - complete!")
    }
    
    func totalWidth() -> CGFloat {
        var width: CGFloat = 0
        for item in dockItems {
            let isDivider = (item.type == .divider)
            width += isDivider ? dividerWidth : baseSize
            width += spacing
        }
        return width - spacing
    }
    
    func calculateScale(centerX: CGFloat) -> CGFloat {
        guard let mouseX = mouseX else { return 1.0 }
        let dist = abs(mouseX - centerX)
        if dist < influenceRadius {
            let factor = 1.0 - dist / influenceRadius
            return 1.0 + (maxMagnification - 1.0) * (factor * factor)
        }
        return 1.0
    }
    
    func handleClick(at point: CGPoint) {
        // TODO: Implement click handling
    }
    
    func orthoMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> matrix_float4x4 {
        return matrix_float4x4(columns: (
            vector_float4(2 / (right - left), 0, 0, 0),
            vector_float4(0, 2 / (top - bottom), 0, 0),
            vector_float4(0, 0, -1 / (far - near), 0),
            vector_float4(-(right + left) / (right - left), -(top + bottom) / (top - bottom), -near / (far - near), 1)
        ))
    }
    
    func modelMatrix(x: Float, y: Float, w: Float, h: Float) -> matrix_float4x4 {
        let translation = matrix_float4x4(columns: (
            vector_float4(1, 0, 0, 0),
            vector_float4(0, 1, 0, 0),
            vector_float4(0, 0, 1, 0),
            vector_float4(x, y, 0, 1)
        ))
        
        let scaling = matrix_float4x4(columns: (
            vector_float4(w, 0, 0, 0),
            vector_float4(0, h, 0, 0),
            vector_float4(0, 0, 1, 0),
            vector_float4(0, 0, 0, 1)
        ))
        
        return matrix_multiply(translation, scaling)
    }
}
