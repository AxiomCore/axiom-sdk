import Flutter
import UIKit

public class AxiomRuntimePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {

        let channel = FlutterMethodChannel(
            name: "axiom_runtime_channel",
            binaryMessenger: registrar.messenger()
        )

        let instance = AxiomRuntimePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "initialize":
            guard let args = call.arguments as? [String: Any],
                  let baseUrl = args["baseUrl"] as? String else {
                return result(
                    FlutterError(code: "BAD_ARGS", message: "Expected baseUrl", details: nil)
                )
            }

            let bytes = [UInt8](baseUrl.utf8)
            bytes.withUnsafeBufferPointer { bp in
                let ax = AxiomString(ptr: bp.baseAddress, len: UInt64(bp.count))
                axiom_initialize(ax)
            }
            result(nil)

        case "call":
            guard let args = call.arguments as? [String: Any],
                  let id = args["endpointId"] as? Int,
                  let data = args["input"] as? FlutterStandardTypedData else {
                return result(FlutterError(code: "BAD_ARGS", message: "Invalid args", details: nil))
            }

            let input = data.data

            let response = input.withUnsafeBytes { (bp: UnsafeRawBufferPointer) -> Data in
                let inBuf = AxiomBuffer(
                    ptr: UnsafeMutablePointer(mutating: bp.bindMemory(to: UInt8.self).baseAddress),
                    len: UInt64(bp.count)
                )

                var outBuf = AxiomBuffer(ptr: nil, len: 0)
                let code = axiom_call(UInt32(id), inBuf, &outBuf)

                if code != 0 {
                    return Data()
                }

                let outData = Data(bytes: outBuf.ptr!, count: Int(outBuf.len))
                axiom_free_buffer(outBuf)
                return outData
            }

            result(FlutterStandardTypedData(bytes: response))

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
