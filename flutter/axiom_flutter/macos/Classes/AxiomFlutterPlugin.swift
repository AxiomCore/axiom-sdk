import FlutterMacOS
import Foundation
import AxiomRuntime

public class AxiomFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "axiom_flutter", binaryMessenger: registrar.messenger)
        let instance = AxiomFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        instance.dummySymbolToEnsureLinking()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterMethodNotImplemented)
    }

    
    public func dummySymbolToEnsureLinking() {
        // We reference the symbols here. 
        // Because this is now called in register(), the linker cannot strip these.
        _ = axiom_initialize
        _ = axiom_load_contract
        _ = axiom_call
        _ = axiom_process_responses
    }
}