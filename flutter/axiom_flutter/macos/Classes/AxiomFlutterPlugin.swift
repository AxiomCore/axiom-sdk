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
        // Every C function Dart looks up with DynamicLibrary.process() (all
        // defined in the same object of libaxiom_runtime.a, published 0.148.6).
        // Optional newer functions are looked up with providesSymbol only.
        _ = axiom_abi_version
        _ = axiom_call
        _ = axiom_cancel
        _ = axiom_clear_auth_token
        _ = axiom_clear_callback
        _ = axiom_contract_reader_version
        _ = axiom_data_abi_version
        _ = axiom_extension_audit
        _ = axiom_extension_invoke
        _ = axiom_extension_lifecycle
        _ = axiom_extension_load_locked
        _ = axiom_free_buffer
        _ = axiom_free_memory
        _ = axiom_free_response_buffer
        _ = axiom_initialize
        _ = axiom_load_contract
        _ = axiom_load_contract_locked
        _ = axiom_malloc
        _ = axiom_process_responses
        _ = axiom_provide_auth_token
        _ = axiom_register_auth_provider
        _ = axiom_register_callback
        _ = axiom_reset_session
        _ = axiom_send_stream_message
        _ = axiom_set_auth_token
    }
}