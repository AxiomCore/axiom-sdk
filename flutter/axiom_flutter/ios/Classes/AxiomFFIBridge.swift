import Foundation

public struct AxiomString {
    public let ptr: UnsafePointer<UInt8>?
    public let len: UInt64
}

public struct AxiomBuffer {
    public let ptr: UnsafeMutablePointer<UInt8>?
    public let len: UInt64
}

@_silgen_name("axiom_initialize")
public func axiom_initialize(_ s: AxiomString)

@_silgen_name("axiom_call")
public func axiom_call(
    _ endpointId: UInt32,
    _ input: AxiomBuffer,
    _ output: UnsafeMutablePointer<AxiomBuffer>
) -> Int32

@_silgen_name("axiom_free_buffer")
public func axiom_free_buffer(_ buf: AxiomBuffer)
