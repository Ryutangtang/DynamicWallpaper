import AppKit
import Metal
import MetalKit

class MetalAnimationView: MTKView, MTKViewDelegate {
    private var commandQueue: MTLCommandQueue!
    private var pipelineStates: [AnimationPreset: MTLRenderPipelineState] = [:]
    private var controller: AnimationController
    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    // Uniform buffer
    struct Uniforms {
        var time: Float
        var resolution: SIMD2<Float>
    }

    init(frame: NSRect, controller: AnimationController) {
        self.controller = controller
        let device = MTLCreateSystemDefaultDevice()!
        super.init(frame: frame, device: device)
        self.delegate = self
        self.framebufferOnly = true
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        self.colorPixelFormat = .bgra8Unorm
        self.preferredFramesPerSecond = 60
        setupPipelines()
    }

    required init(coder: NSCoder) { fatalError() }

    private func setupPipelines() {
        guard let device = device else { return }
        commandQueue = device.makeCommandQueue()

        let library = try! device.makeDefaultLibrary(bundle: .main)

        for preset in AnimationPreset.allCases {
            let fragmentName = "fragment_\(preset.rawValue)"
            guard let fragment = library.makeFunction(name: fragmentName),
                  let vertex = library.makeFunction(name: "vertex_fullscreen") else { continue }

            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertex
            desc.fragmentFunction = fragment
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm

            if let state = try? device.makeRenderPipelineState(descriptor: desc) {
                pipelineStates[preset] = state
            }
        }
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        let delta = Float(now - lastTime)
        lastTime = now
        controller.tick(delta: delta)

        guard
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
            let pipeline = pipelineStates[controller.currentPreset]
        else { return }

        var uniforms = Uniforms(
            time: controller.time,
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
