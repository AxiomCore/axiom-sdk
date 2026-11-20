// Web: size of the Axiom wasm linear memory (bytes), read through the
// already-initialised wasm_bindgen glue (it returns the cached exports).
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<int?> wasmMemoryBytes() async {
  final bindgen = globalContext['wasm_bindgen'];
  if (bindgen == null) return null;
  final exports =
      await ((bindgen as JSFunction).callAsFunction(null) as JSPromise).toDart
          as JSObject;
  final memory = exports['memory'] as JSObject;
  final buffer = memory['buffer'] as JSObject;
  return (buffer['byteLength'] as JSNumber).toDartInt;
}
