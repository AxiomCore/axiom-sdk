Project Root: /Users/yashmakan/AxiomCore/axiom-sdk/flutter/axiom_flutter
Project Structure:
```
.
|-- .gitignore
|-- .metadata
|-- CHANGELOG.md
|-- LICENSE
|-- README.md
|-- analysis_options.yaml
|-- ios
    |-- Classes
        |-- AxiomFlutterPlugin.swift
    |-- Frameworks
        |-- AxiomRuntime.xcframework
            |-- Info.plist
            |-- ios-arm64
                |-- Headers
                    |-- axiom.h
                    |-- module.modulemap
            |-- ios-arm64_x86_64-simulator
                |-- Headers
                    |-- axiom.h
                    |-- module.modulemap
            |-- macos-arm64_x86_64
                |-- Headers
                    |-- axiom.h
                    |-- module.modulemap
    |-- axiom_flutter.podspec
|-- lib
    |-- assets
        |-- wasm
            |-- axiom_runtime.js
    |-- axiom_flutter.dart
    |-- src
        |-- channel.dart
        |-- config.dart
        |-- extensions.dart
        |-- internal
            |-- axiom_codec.dart
            |-- query_key.dart
            |-- tracing.dart
        |-- mutation.dart
        |-- query.dart
        |-- query_manager.dart
        |-- runtime_interface.dart
        |-- runtime_io.dart
        |-- runtime_stub.dart
        |-- runtime_web.dart
        |-- state.dart
        |-- widgets
            |-- axiom_builder.dart
            |-- axiom_mutation_builder.dart
|-- macos
    |-- Classes
        |-- AxiomFlutterPlugin.swift
    |-- axiom_flutter.podspec
|-- pubspec.yaml
|-- test

```

---
## File: lib/assets/wasm/axiom_runtime.js

```js
let wasm_bindgen = (function(exports) {
    let script_src;
    if (typeof document !== 'undefined' && document.currentScript !== null) {
        script_src = new URL(document.currentScript.src, location.href).toString();
    }
    function __wbg_get_imports() {
        const import0 = {
            __proto__: null,
            __wbg___wbindgen_boolean_get_6ea149f0a8dcc5ff: function(arg0) {
                const v = getObject(arg0);
                const ret = typeof(v) === 'boolean' ? v : undefined;
                return isLikeNone(ret) ? 0xFFFFFF : ret ? 1 : 0;
            },
            __wbg___wbindgen_debug_string_ab4b34d23d6778bd: function(arg0, arg1) {
                const ret = debugString(getObject(arg1));
                const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_export, wasm.__wbindgen_export2);
                const len1 = WASM_VECTOR_LEN;
                getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
                getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
            },
            __wbg___wbindgen_is_function_3baa9db1a987f47d: function(arg0) {
                const ret = typeof(getObject(arg0)) === 'function';
                return ret;
            },
            __wbg___wbindgen_is_object_63322ec0cd6ea4ef: function(arg0) {
                const val = getObject(arg0);
                const ret = typeof(val) === 'object' && val !== null;
                return ret;
            },
            __wbg___wbindgen_is_string_6df3bf7ef1164ed3: function(arg0) {
                const ret = typeof(getObject(arg0)) === 'string';
                return ret;
            },
            __wbg___wbindgen_is_undefined_29a43b4d42920abd: function(arg0) {
                const ret = getObject(arg0) === undefined;
                return ret;
            },
            __wbg___wbindgen_string_get_7ed5322991caaec5: function(arg0, arg1) {
                const obj = getObject(arg1);
                const ret = typeof(obj) === 'string' ? obj : undefined;
                var ptr1 = isLikeNone(ret) ? 0 : passStringToWasm0(ret, wasm.__wbindgen_export, wasm.__wbindgen_export2);
                var len1 = WASM_VECTOR_LEN;
                getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
                getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
            },
            __wbg___wbindgen_throw_6b64449b9b9ed33c: function(arg0, arg1) {
                throw new Error(getStringFromWasm0(arg0, arg1));
            },
            __wbg__wbg_cb_unref_b46c9b5a9f08ec37: function(arg0) {
                getObject(arg0)._wbg_cb_unref();
            },
            __wbg_abort_4ce5b484434ef6fd: function(arg0) {
                getObject(arg0).abort();
            },
            __wbg_append_e8fc56ce7c00e874: function() { return handleError(function (arg0, arg1, arg2, arg3, arg4) {
                getObject(arg0).append(getStringFromWasm0(arg1, arg2), getStringFromWasm0(arg3, arg4));
            }, arguments); },
            __wbg_arrayBuffer_848c392b70c67d3d: function() { return handleError(function (arg0) {
                const ret = getObject(arg0).arrayBuffer();
                return addHeapObject(ret);
            }, arguments); },
            __wbg_axiom_web_callback_da6bff810821623d: function(arg0, arg1, arg2, arg3, arg4, arg5, arg6) {
                axiom_web_callback(arg0, arg1, arg2, arg3 >>> 0, arg4 >>> 0, arg5 >>> 0, arg6 >>> 0);
            },
            __wbg_body_0c3a51aec038a31a: function(arg0) {
                const ret = getObject(arg0).body;
                return isLikeNone(ret) ? 0 : addHeapObject(ret);
            },
            __wbg_buffer_d0f5ea0926a691fd: function(arg0) {
                const ret = getObject(arg0).buffer;
                return addHeapObject(ret);
            },
            __wbg_call_14b169f759b26747: function() { return handleError(function (arg0, arg1) {
                const ret = getObject(arg0).call(getObject(arg1));
                return addHeapObject(ret);
            }, arguments); },
            __wbg_call_a24592a6f349a97e: function() { return handleError(function (arg0, arg1, arg2) {
                const ret = getObject(arg0).call(getObject(arg1), getObject(arg2));
                return addHeapObject(ret);
            }, arguments); },
            __wbg_clearInterval_16e8cbbce92291d0: function(arg0) {
                const ret = clearInterval(takeObject(arg0));
                return addHeapObject(ret);
            },
            __wbg_clearTimeout_113b1cde814ec762: function(arg0) {
                const ret = clearTimeout(takeObject(arg0));
                return addHeapObject(ret);
            },
            __wbg_crypto_38df2bab126b63dc: function(arg0) {
                const ret = getObject(arg0).crypto;
                return addHeapObject(ret);
            },
            __wbg_data_bb9dffdd1e99cf2d: function(arg0) {
                const ret = getObject(arg0).data;
                return addHeapObject(ret);
            },
            __wbg_done_9158f7cc8751ba32: function(arg0) {
                const ret = getObject(arg0).done;
                return ret;
            },
            __wbg_error_2001591ad2463697: function(arg0) {
                console.error(getObject(arg0));
            },
            __wbg_fetch_0d322c0aed196b8b: function(arg0, arg1) {
                const ret = getObject(arg0).fetch(getObject(arg1));
                return addHeapObject(ret);
            },
            __wbg_fetch_9ea633a8592ee39a: function(arg0, arg1) {
                const ret = getObject(arg0).fetch(getObject(arg1));
                return addHeapObject(ret);
            },
            __wbg_fetch_fda7bc27c982b1f3: function(arg0) {
                const ret = fetch(getObject(arg0));
                return addHeapObject(ret);
            },
            __wbg_getItem_7fe1351b9ea3b2f3: function() { return handleError(function (arg0, arg1, arg2, arg3) {
                const ret = getObject(arg1).getItem(getStringFromWasm0(arg2, arg3));
                var ptr1 = isLikeNone(ret) ? 0 : passStringToWasm0(ret, wasm.__wbindgen_export, wasm.__wbindgen_export2);
                var len1 = WASM_VECTOR_LEN;
                getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
                getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
            }, arguments); },
            __wbg_getRandomValues_c44a50d8cfdaebeb: function() { return handleError(function (arg0, arg1) {
                getObject(arg0).getRandomValues(getObject(arg1));
            }, arguments); },
            __wbg_getReader_9094ac3b37a7d171: function(arg0) {
                const ret = getObject(arg0).getReader();
                return addHeapObject(ret);
            },
            __wbg_get_1affdbdd5573b16a: function() { return handleError(function (arg0, arg1) {
                const ret = Reflect.get(getObject(arg0), getObject(arg1));
                return addHeapObject(ret);
            }, arguments); },
            __wbg_get_6011fa3a58f61074: function() { return handleError(function (arg0, arg1) {
                const ret = Reflect.get(getObject(arg0), getObject(arg1));
                return addHeapObject(ret);
            }, arguments); },
            __wbg_has_880f1d472f7cecba: function() { return handleError(function (arg0, arg1) {
                const ret = Reflect.has(getObject(arg0), getObject(arg1));
                return ret;
            }, arguments); },
            __wbg_headers_6022deb4e576fb8e: function(arg0) {
                const ret = getObject(arg0).headers;
                return addHeapObject(ret);
            },
            __wbg_instanceof_ArrayBuffer_7c8433c6ed14ffe3: function(arg0) {
                let result;
                try {
                    result = getObject(arg0) instanceof ArrayBuffer;
                } catch (_) {
                    result = false;
                }
                const ret = result;
                return ret;
            },
            __wbg_instanceof_ReadableStreamDefaultReader_02bfe747638fa274: function(arg0) {
                let result;
                try {
                    result = getObject(arg0) instanceof ReadableStreamDefaultReader;
                } catch (_) {
                    result = false;
                }
                const ret = result;
                return ret;
            },
            __wbg_instanceof_Response_9b2d111407865ff2: function(arg0) {
                let result;
                try {
                    result = getObject(arg0) instanceof Response;
                } catch (_) {
                    result = false;
                }
                const ret = result;
                return ret;
            },
            __wbg_instanceof_Window_cc64c86c8ef9e02b: function(arg0) {
                let result;
                try {
                    result = getObject(arg0) instanceof Window;
                } catch (_) {
                    result = false;
                }
                const ret = result;
                return ret;
            },
            __wbg_iterator_013bc09ec998c2a7: function() {
                const ret = Symbol.iterator;
                return addHeapObject(ret);
            },
            __wbg_length_9f1775224cf1d815: function(arg0) {
                const ret = getObject(arg0).length;
                return ret;
            },
            __wbg_localStorage_f5f66b1ffd2486bc: function() { return handleError(function (arg0) {
                const ret = getObject(arg0).localStorage;
                return isLikeNone(ret) ? 0 : addHeapObject(ret);
            }, arguments); },
            __wbg_log_0c201ade58bb55e1: function(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) {
                let deferred0_0;
                let deferred0_1;
                try {
                    deferred0_0 = arg0;
                    deferred0_1 = arg1;
                    console.log(getStringFromWasm0(arg0, arg1), getStringFromWasm0(arg2, arg3), getStringFromWasm0(arg4, arg5), getStringFromWasm0(arg6, arg7));
                } finally {
                    wasm.__wbindgen_export4(deferred0_0, deferred0_1, 1);
                }
            },
            __wbg_log_7e1aa9064a1dbdbd: function(arg0) {
                console.log(getObject(arg0));
            },
            __wbg_log_ce2c4456b290c5e7: function(arg0, arg1) {
                let deferred0_0;
                let deferred0_1;
                try {
                    deferred0_0 = arg0;
                    deferred0_1 = arg1;
                    console.log(getStringFromWasm0(arg0, arg1));
                } finally {
                    wasm.__wbindgen_export4(deferred0_0, deferred0_1, 1);
                }
            },
            __wbg_mark_b4d943f3bc2d2404: function(arg0, arg1) {
                performance.mark(getStringFromWasm0(arg0, arg1));
            },
            __wbg_measure_84362959e621a2c1: function() { return handleError(function (arg0, arg1, arg2, arg3) {
                let deferred0_0;
                let deferred0_1;
                let deferred1_0;
                let deferred1_1;
                try {
                    deferred0_0 = arg0;
                    deferred0_1 = arg1;
                    deferred1_0 = arg2;
                    deferred1_1 = arg3;
                    performance.measure(getStringFromWasm0(arg0, arg1), getStringFromWasm0(arg2, arg3));
                } finally {
                    wasm.__wbindgen_export4(deferred0_0, deferred0_1, 1);
                    wasm.__wbindgen_export4(deferred1_0, deferred1_1, 1);
                }
            }, arguments); },
            __wbg_msCrypto_bd5a034af96bcba6: function(arg0) {
                const ret = getObject(arg0).msCrypto;
                return addHeapObject(ret);
            },
            __wbg_new_0c7403db6e782f19: function(arg0) {
                const ret = new Uint8Array(getObject(arg0));
                return addHeapObject(ret);
            },
            __wbg_new_15a4889b4b90734d: function() { return handleError(function () {
                const ret = new Headers();
                return addHeapObject(ret);
            }, arguments); },
            __wbg_new_2a6e9133304ae2bf: function() { return handleError(function (arg0, arg1) {
                const ret = new WebSocket(getStringFromWasm0(arg0, arg1));
                return addHeapObject(ret);
            }, arguments); },
            __wbg_new_98c22165a42231aa: function() { return handleError(function () {
                const ret = new AbortController();
                return addHeapObject(ret);
            }, arguments); },
            __wbg_new_aa8d0fa9762c29bd: function() {
                const ret = new Object();
                return addHeapObject(ret);
            },
            __wbg_new_from_slice_b5ea43e23f6008c0: function(arg0, arg1) {
                const ret = new Uint8Array(getArrayU8FromWasm0(arg0, arg1));
                return addHeapObject(ret);
            },
            __wbg_new_with_length_8c854e41ea4dae9b: function(arg0) {
                const ret = new Uint8Array(arg0 >>> 0);
                return addHeapObject(ret);
            },
            __wbg_new_with_str_and_init_897be1708e42f39d: function() { return handleError(function (arg0, arg1, arg2) {
                const ret = new Request(getStringFromWasm0(arg0, arg1), getObject(arg2));
                return addHeapObject(ret);
            }, arguments); },
            __wbg_next_0340c4ae324393c3: function() { return handleError(function (arg0) {
                const ret = getObject(arg0).next();
                return addHeapObject(ret);
            }, arguments); },
            __wbg_next_7646edaa39458ef7: function(arg0) {
                const ret = getObject(arg0).next;
                return addHeapObject(ret);
            },
            __wbg_node_84ea875411254db1: function(arg0) {
                const ret = getObject(arg0).node;
                return addHeapObject(ret);
            },
            __wbg_now_a9b7df1cbee90986: function() {
                const ret = Date.now();
                return ret;
            },
            __wbg_now_cace042f68c814d8: function(arg0) {
                const ret = getObject(arg0).now();
                return ret;
            },
            __wbg_performance_5fc5a6563dcd33de: function(arg0) {
                const ret = getObject(arg0).performance;
                return addHeapObject(ret);
            },
            __wbg_process_44c7a14e11e9f69e: function(arg0) {
                const ret = getObject(arg0).process;
                return addHeapObject(ret);
            },
            __wbg_prototypesetcall_a6b02eb00b0f4ce2: function(arg0, arg1, arg2) {
                Uint8Array.prototype.set.call(getArrayU8FromWasm0(arg0, arg1), getObject(arg2));
            },
            __wbg_queueMicrotask_5d15a957e6aa920e: function(arg0) {
                queueMicrotask(getObject(arg0));
            },
            __wbg_queueMicrotask_f8819e5ffc402f36: function(arg0) {
                const ret = getObject(arg0).queueMicrotask;
                return addHeapObject(ret);
            },
            __wbg_randomFillSync_6c25eac9869eb53c: function() { return handleError(function (arg0, arg1) {
                getObject(arg0).randomFillSync(takeObject(arg1));
            }, arguments); },
            __wbg_read_ddc2d178d2e57272: function(arg0) {
                const ret = getObject(arg0).read();
                return addHeapObject(ret);
            },
            __wbg_removeItem_487c385a3066a8ed: function() { return handleError(function (arg0, arg1, arg2) {
                getObject(arg0).removeItem(getStringFromWasm0(arg1, arg2));
            }, arguments); },
            __wbg_require_b4edbdcf3e2a1ef0: function() { return handleError(function () {
                const ret = module.require;
                return addHeapObject(ret);
            }, arguments); },
            __wbg_resolve_e6c466bc1052f16c: function(arg0) {
                const ret = Promise.resolve(getObject(arg0));
                return addHeapObject(ret);
            },
            __wbg_send_15358dbe221c6258: function() { return handleError(function (arg0, arg1, arg2) {
                getObject(arg0).send(getStringFromWasm0(arg1, arg2));
            }, arguments); },
            __wbg_send_9ee7ecd8802698d0: function() { return handleError(function (arg0, arg1) {
                getObject(arg0).send(getObject(arg1));
            }, arguments); },
            __wbg_setInterval_84b64f01452a246e: function() { return handleError(function (arg0, arg1) {
                const ret = setInterval(getObject(arg0), arg1);
                return addHeapObject(ret);
            }, arguments); },
            __wbg_setItem_e6399d3faae141dc: function() { return handleError(function (arg0, arg1, arg2, arg3, arg4) {
                getObject(arg0).setItem(getStringFromWasm0(arg1, arg2), getStringFromWasm0(arg3, arg4));
            }, arguments); },
            __wbg_setTimeout_ef24d2fc3ad97385: function() { return handleError(function (arg0, arg1) {
                const ret = setTimeout(getObject(arg0), arg1);
                return addHeapObject(ret);
            }, arguments); },
            __wbg_set_binaryType_770e68648ca5e83d: function(arg0, arg1) {
                getObject(arg0).binaryType = __wbindgen_enum_BinaryType[arg1];
            },
            __wbg_set_body_be11680f34217f75: function(arg0, arg1) {
                getObject(arg0).body = getObject(arg1);
            },
            __wbg_set_credentials_6577be90e0e85eb6: function(arg0, arg1) {
                getObject(arg0).credentials = __wbindgen_enum_RequestCredentials[arg1];
            },
            __wbg_set_headers_50fc01786240a440: function(arg0, arg1) {
                getObject(arg0).headers = getObject(arg1);
            },
            __wbg_set_method_c9f1f985f6b6c427: function(arg0, arg1, arg2) {
                getObject(arg0).method = getStringFromWasm0(arg1, arg2);
            },
            __wbg_set_mode_5e08d503428c06b9: function(arg0, arg1) {
                getObject(arg0).mode = __wbindgen_enum_RequestMode[arg1];
            },
            __wbg_set_onclose_17fa3bbcc4ba3541: function(arg0, arg1) {
                getObject(arg0).onclose = getObject(arg1);
            },
            __wbg_set_onerror_da99c4232662a084: function(arg0, arg1) {
                getObject(arg0).onerror = getObject(arg1);
            },
            __wbg_set_onmessage_c1db358b9c38e3f1: function(arg0, arg1) {
                getObject(arg0).onmessage = getObject(arg1);
            },
            __wbg_set_signal_1d4e73c2305a0e7c: function(arg0, arg1) {
                getObject(arg0).signal = getObject(arg1);
            },
            __wbg_signal_fdc54643b47bf85b: function(arg0) {
                const ret = getObject(arg0).signal;
                return addHeapObject(ret);
            },
            __wbg_static_accessor_GLOBAL_8cfadc87a297ca02: function() {
                const ret = typeof global === 'undefined' ? null : global;
                return isLikeNone(ret) ? 0 : addHeapObject(ret);
            },
            __wbg_static_accessor_GLOBAL_THIS_602256ae5c8f42cf: function() {
                const ret = typeof globalThis === 'undefined' ? null : globalThis;
                return isLikeNone(ret) ? 0 : addHeapObject(ret);
            },
            __wbg_static_accessor_SELF_e445c1c7484aecc3: function() {
                const ret = typeof self === 'undefined' ? null : self;
                return isLikeNone(ret) ? 0 : addHeapObject(ret);
            },
            __wbg_static_accessor_WINDOW_f20e8576ef1e0f17: function() {
                const ret = typeof window === 'undefined' ? null : window;
                return isLikeNone(ret) ? 0 : addHeapObject(ret);
            },
            __wbg_status_43e0d2f15b22d69f: function(arg0) {
                const ret = getObject(arg0).status;
                return ret;
            },
            __wbg_stringify_91082ed7a5a5769e: function() { return handleError(function (arg0) {
                const ret = JSON.stringify(getObject(arg0));
                return addHeapObject(ret);
            }, arguments); },
            __wbg_subarray_f8ca46a25b1f5e0d: function(arg0, arg1, arg2) {
                const ret = getObject(arg0).subarray(arg1 >>> 0, arg2 >>> 0);
                return addHeapObject(ret);
            },
            __wbg_then_792e0c862b060889: function(arg0, arg1, arg2) {
                const ret = getObject(arg0).then(getObject(arg1), getObject(arg2));
                return addHeapObject(ret);
            },
            __wbg_then_8e16ee11f05e4827: function(arg0, arg1) {
                const ret = getObject(arg0).then(getObject(arg1));
                return addHeapObject(ret);
            },
            __wbg_url_2bf741820e6563a0: function(arg0, arg1) {
                const ret = getObject(arg1).url;
                const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_export, wasm.__wbindgen_export2);
                const len1 = WASM_VECTOR_LEN;
                getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
                getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
            },
            __wbg_value_ee3a06f4579184fa: function(arg0) {
                const ret = getObject(arg0).value;
                return addHeapObject(ret);
            },
            __wbg_versions_276b2795b1c6a219: function(arg0) {
                const ret = getObject(arg0).versions;
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000001: function(arg0, arg1) {
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [Externref], shim_idx: 193, ret: Result(Unit), inner_ret: Some(Result(Unit)) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_2379);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000002: function(arg0, arg1) {
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [NamedExternref("Event")], shim_idx: 45, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_500);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000003: function(arg0, arg1) {
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [NamedExternref("MessageEvent")], shim_idx: 45, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_500_2);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000004: function(arg0, arg1) {
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [], shim_idx: 107, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_2219);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000005: function(arg0, arg1) {
                // Cast intrinsic for `Ref(Slice(U8)) -> NamedExternref("Uint8Array")`.
                const ret = getArrayU8FromWasm0(arg0, arg1);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000006: function(arg0, arg1) {
                // Cast intrinsic for `Ref(String) -> Externref`.
                const ret = getStringFromWasm0(arg0, arg1);
                return addHeapObject(ret);
            },
            __wbindgen_object_clone_ref: function(arg0) {
                const ret = getObject(arg0);
                return addHeapObject(ret);
            },
            __wbindgen_object_drop_ref: function(arg0) {
                takeObject(arg0);
            },
        };
        return {
            __proto__: null,
            "./axiom_runtime_bg.js": import0,
        };
    }

    function __wasm_bindgen_func_elem_2219(arg0, arg1) {
        wasm.__wasm_bindgen_func_elem_2219(arg0, arg1);
    }

    function __wasm_bindgen_func_elem_500(arg0, arg1, arg2) {
        wasm.__wasm_bindgen_func_elem_500(arg0, arg1, addHeapObject(arg2));
    }

    function __wasm_bindgen_func_elem_500_2(arg0, arg1, arg2) {
        wasm.__wasm_bindgen_func_elem_500_2(arg0, arg1, addHeapObject(arg2));
    }

    function __wasm_bindgen_func_elem_2379(arg0, arg1, arg2) {
        try {
            const retptr = wasm.__wbindgen_add_to_stack_pointer(-16);
            wasm.__wasm_bindgen_func_elem_2379(retptr, arg0, arg1, addHeapObject(arg2));
            var r0 = getDataViewMemory0().getInt32(retptr + 4 * 0, true);
            var r1 = getDataViewMemory0().getInt32(retptr + 4 * 1, true);
            if (r1) {
                throw takeObject(r0);
            }
        } finally {
            wasm.__wbindgen_add_to_stack_pointer(16);
        }
    }


    const __wbindgen_enum_BinaryType = ["blob", "arraybuffer"];


    const __wbindgen_enum_RequestCredentials = ["omit", "same-origin", "include"];


    const __wbindgen_enum_RequestMode = ["same-origin", "no-cors", "cors", "navigate"];

    function addHeapObject(obj) {
        if (heap_next === heap.length) heap.push(heap.length + 1);
        const idx = heap_next;
        heap_next = heap[idx];

        heap[idx] = obj;
        return idx;
    }

    const CLOSURE_DTORS = (typeof FinalizationRegistry === 'undefined')
        ? { register: () => {}, unregister: () => {} }
        : new FinalizationRegistry(state => wasm.__wbindgen_export5(state.a, state.b));

    function debugString(val) {
        // primitive types
        const type = typeof val;
        if (type == 'number' || type == 'boolean' || val == null) {
            return  `${val}`;
        }
        if (type == 'string') {
            return `"${val}"`;
        }
        if (type == 'symbol') {
            const description = val.description;
            if (description == null) {
                return 'Symbol';
            } else {
                return `Symbol(${description})`;
            }
        }
        if (type == 'function') {
            const name = val.name;
            if (typeof name == 'string' && name.length > 0) {
                return `Function(${name})`;
            } else {
                return 'Function';
            }
        }
        // objects
        if (Array.isArray(val)) {
            const length = val.length;
            let debug = '[';
            if (length > 0) {
                debug += debugString(val[0]);
            }
            for(let i = 1; i < length; i++) {
                debug += ', ' + debugString(val[i]);
            }
            debug += ']';
            return debug;
        }
        // Test for built-in
        const builtInMatches = /\[object ([^\]]+)\]/.exec(toString.call(val));
        let className;
        if (builtInMatches && builtInMatches.length > 1) {
            className = builtInMatches[1];
        } else {
            // Failed to match the standard '[object ClassName]'
            return toString.call(val);
        }
        if (className == 'Object') {
            // we're a user defined class or Object
            // JSON.stringify avoids problems with cycles, and is generally much
            // easier than looping through ownProperties of `val`.
            try {
                return 'Object(' + JSON.stringify(val) + ')';
            } catch (_) {
                return 'Object';
            }
        }
        // errors
        if (val instanceof Error) {
            return `${val.name}: ${val.message}\n${val.stack}`;
        }
        // TODO we could test for more things here, like `Set`s and `Map`s.
        return className;
    }

    function dropObject(idx) {
        if (idx < 1028) return;
        heap[idx] = heap_next;
        heap_next = idx;
    }

    function getArrayU8FromWasm0(ptr, len) {
        ptr = ptr >>> 0;
        return getUint8ArrayMemory0().subarray(ptr / 1, ptr / 1 + len);
    }

    let cachedDataViewMemory0 = null;
    function getDataViewMemory0() {
        if (cachedDataViewMemory0 === null || cachedDataViewMemory0.buffer.detached === true || (cachedDataViewMemory0.buffer.detached === undefined && cachedDataViewMemory0.buffer !== wasm.memory.buffer)) {
            cachedDataViewMemory0 = new DataView(wasm.memory.buffer);
        }
        return cachedDataViewMemory0;
    }

    function getStringFromWasm0(ptr, len) {
        ptr = ptr >>> 0;
        return decodeText(ptr, len);
    }

    let cachedUint8ArrayMemory0 = null;
    function getUint8ArrayMemory0() {
        if (cachedUint8ArrayMemory0 === null || cachedUint8ArrayMemory0.byteLength === 0) {
            cachedUint8ArrayMemory0 = new Uint8Array(wasm.memory.buffer);
        }
        return cachedUint8ArrayMemory0;
    }

    function getObject(idx) { return heap[idx]; }

    function handleError(f, args) {
        try {
            return f.apply(this, args);
        } catch (e) {
            wasm.__wbindgen_export3(addHeapObject(e));
        }
    }

    let heap = new Array(1024).fill(undefined);
    heap.push(undefined, null, true, false);

    let heap_next = heap.length;

    function isLikeNone(x) {
        return x === undefined || x === null;
    }

    function makeMutClosure(arg0, arg1, f) {
        const state = { a: arg0, b: arg1, cnt: 1 };
        const real = (...args) => {

            // First up with a closure we increment the internal reference
            // count. This ensures that the Rust closure environment won't
            // be deallocated while we're invoking it.
            state.cnt++;
            const a = state.a;
            state.a = 0;
            try {
                return f(a, state.b, ...args);
            } finally {
                state.a = a;
                real._wbg_cb_unref();
            }
        };
        real._wbg_cb_unref = () => {
            if (--state.cnt === 0) {
                wasm.__wbindgen_export5(state.a, state.b);
                state.a = 0;
                CLOSURE_DTORS.unregister(state);
            }
        };
        CLOSURE_DTORS.register(real, state, state);
        return real;
    }

    function passStringToWasm0(arg, malloc, realloc) {
        if (realloc === undefined) {
            const buf = cachedTextEncoder.encode(arg);
            const ptr = malloc(buf.length, 1) >>> 0;
            getUint8ArrayMemory0().subarray(ptr, ptr + buf.length).set(buf);
            WASM_VECTOR_LEN = buf.length;
            return ptr;
        }

        let len = arg.length;
        let ptr = malloc(len, 1) >>> 0;

        const mem = getUint8ArrayMemory0();

        let offset = 0;

        for (; offset < len; offset++) {
            const code = arg.charCodeAt(offset);
            if (code > 0x7F) break;
            mem[ptr + offset] = code;
        }
        if (offset !== len) {
            if (offset !== 0) {
                arg = arg.slice(offset);
            }
            ptr = realloc(ptr, len, len = offset + arg.length * 3, 1) >>> 0;
            const view = getUint8ArrayMemory0().subarray(ptr + offset, ptr + len);
            const ret = cachedTextEncoder.encodeInto(arg, view);

            offset += ret.written;
            ptr = realloc(ptr, len, offset, 1) >>> 0;
        }

        WASM_VECTOR_LEN = offset;
        return ptr;
    }

    function takeObject(idx) {
        const ret = getObject(idx);
        dropObject(idx);
        return ret;
    }

    let cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
    cachedTextDecoder.decode();
    function decodeText(ptr, len) {
        return cachedTextDecoder.decode(getUint8ArrayMemory0().subarray(ptr, ptr + len));
    }

    const cachedTextEncoder = new TextEncoder();

    if (!('encodeInto' in cachedTextEncoder)) {
        cachedTextEncoder.encodeInto = function (arg, view) {
            const buf = cachedTextEncoder.encode(arg);
            view.set(buf);
            return {
                read: arg.length,
                written: buf.length
            };
        };
    }

    let WASM_VECTOR_LEN = 0;

    let wasmModule, wasm;
    function __wbg_finalize_init(instance, module) {
        wasm = instance.exports;
        wasmModule = module;
        cachedDataViewMemory0 = null;
        cachedUint8ArrayMemory0 = null;
        return wasm;
    }

    async function __wbg_load(module, imports) {
        if (typeof Response === 'function' && module instanceof Response) {
            if (typeof WebAssembly.instantiateStreaming === 'function') {
                try {
                    return await WebAssembly.instantiateStreaming(module, imports);
                } catch (e) {
                    const validResponse = module.ok && expectedResponseType(module.type);

                    if (validResponse && module.headers.get('Content-Type') !== 'application/wasm') {
                        console.warn("`WebAssembly.instantiateStreaming` failed because your server does not serve Wasm with `application/wasm` MIME type. Falling back to `WebAssembly.instantiate` which is slower. Original error:\n", e);

                    } else { throw e; }
                }
            }

            const bytes = await module.arrayBuffer();
            return await WebAssembly.instantiate(bytes, imports);
        } else {
            const instance = await WebAssembly.instantiate(module, imports);

            if (instance instanceof WebAssembly.Instance) {
                return { instance, module };
            } else {
                return instance;
            }
        }

        function expectedResponseType(type) {
            switch (type) {
                case 'basic': case 'cors': case 'default': return true;
            }
            return false;
        }
    }

    function initSync(module) {
        if (wasm !== undefined) return wasm;


        if (module !== undefined) {
            if (Object.getPrototypeOf(module) === Object.prototype) {
                ({module} = module)
            } else {
                console.warn('using deprecated parameters for `initSync()`; pass a single object instead')
            }
        }

        const imports = __wbg_get_imports();
        if (!(module instanceof WebAssembly.Module)) {
            module = new WebAssembly.Module(module);
        }
        const instance = new WebAssembly.Instance(module, imports);
        return __wbg_finalize_init(instance, module);
    }

    async function __wbg_init(module_or_path) {
        if (wasm !== undefined) return wasm;


        if (module_or_path !== undefined) {
            if (Object.getPrototypeOf(module_or_path) === Object.prototype) {
                ({module_or_path} = module_or_path)
            } else {
                console.warn('using deprecated parameters for the initialization function; pass a single object instead')
            }
        }

        if (module_or_path === undefined && script_src !== undefined) {
            module_or_path = script_src.replace(/\.js$/, "_bg.wasm");
        }
        const imports = __wbg_get_imports();

        if (typeof module_or_path === 'string' || (typeof Request === 'function' && module_or_path instanceof Request) || (typeof URL === 'function' && module_or_path instanceof URL)) {
            module_or_path = fetch(module_or_path);
        }

        const { instance, module } = await __wbg_load(await module_or_path, imports);

        return __wbg_finalize_init(instance, module);
    }

    return Object.assign(__wbg_init, { initSync }, exports);
})({ __proto__: null });

```
---
## File: lib/axiom_flutter.dart

```dart
library;

export 'src/runtime_interface.dart';
export 'src/state.dart';
export 'src/query.dart';
export 'src/mutation.dart';
export 'src/channel.dart';
export 'src/config.dart';
export 'src/widgets/axiom_builder.dart';
export 'src/widgets/axiom_mutation_builder.dart';
export 'src/extensions.dart';

```
---
## File: lib/src/channel.dart

```dart
import 'dart:async';
import 'state.dart';
import 'runtime_interface.dart';
import 'internal/axiom_codec.dart';

/// Returned by SDK endpoints defined as `http_stream`, `sse`, or `file_stream`.
class AxiomStreamQuery<T> {
  final Stream<AxiomState<T>> stream;
  AxiomStreamQuery(this.stream);
}

/// Returned by SDK endpoints defined as `websocket`.
/// Provides a bidirectional communication channel.
class AxiomChannel<ReceiveType, SendType> {
  final int _requestId;
  final Stream<AxiomState<ReceiveType>> stream;
  final AxiomRuntime _runtime;

  AxiomChannel(this._requestId, this.stream, this._runtime);

  /// Sends a message up to the server via the active WebSocket.
  void send(SendType data) {
    // Pass null for headers since WebSockets don't use HTTP-style content-type per frame.
    final bytes = AxiomCodec.encodeBody(data, null);
    _runtime.sendStreamMessage(requestId: _requestId, payload: bytes);
  }
}

```
---
## File: lib/src/config.dart

```dart
// FILE: lib/src/config.dart

class AxiomContractConfig {
  final String baseUrl;
  final String assetPath; // e.g., 'assets/.axiom'

  const AxiomContractConfig({required this.baseUrl, required this.assetPath});
}

class AxiomConfig {
  final Map<String, AxiomContractConfig> contracts;
  final bool debug;
  final String? dbPath;

  const AxiomConfig({required this.contracts, this.debug = false, this.dbPath});
}

```
---
## File: lib/src/extensions.dart

```dart
import 'dart:async';
import 'state.dart';

extension AxiomStreamExtensions<T> on Stream<AxiomState<T>> {
  /// Returns a Future that completes with the first valid data received.
  /// Useful for "awaiting" a stream result like a standard API call.
  /// Throws if the stream ends or errors without data.
  Future<T> unwrap() {
    return firstWhere(
      (s) => s.data != null || (s.hasError && !s.isFetching),
    ).then((s) {
      if (s.data != null) return s.data!;
      throw s.error ?? Exception("Stream completed with no data");
    });
  }

  /// Filters the stream to only emit data events.
  Stream<T> onlyData() {
    return where((s) => s.data != null).map((s) => s.data!);
  }

  /// Side effect: Execute callback when data arrives (cache or network).
  Stream<AxiomState<T>> onData(void Function(T data) callback) {
    return map((state) {
      if (state.data != null) callback(state.data as T);
      return state;
    });
  }
}

```
---
## File: lib/src/internal/axiom_codec.dart

```dart
import 'dart:convert';
import 'dart:typed_data';

class AxiomCodec {
  static Uint8List encodeBody(dynamic body, Map<String, String>? headers) {
    if (body == null) return Uint8List(0);
    if (body is Uint8List) return body;
    if (body is String) return Uint8List.fromList(utf8.encode(body));

    // Check if request is URL-encoded form data (e.g. FastAPI OAuth2PasswordRequestForm)
    final isForm =
        headers?.entries.any(
          (e) =>
              e.key.toLowerCase() == 'content-type' &&
              e.value.contains('application/x-www-form-urlencoded'),
        ) ??
        false;

    if (isForm && body is Map) {
      final parts = <String>[];
      body.forEach((key, value) {
        if (value != null) {
          parts.add(
            '${Uri.encodeQueryComponent(key.toString())}=${Uri.encodeQueryComponent(value.toString())}',
          );
        }
      });
      return Uint8List.fromList(utf8.encode(parts.join('&')));
    }

    if (body is DateTime) {
      return Uint8List.fromList(utf8.encode('"${body.toIso8601String()}"'));
    }

    return Uint8List.fromList(utf8.encode(jsonEncode(body)));
  }

  static T decode<T>(Uint8List bytes, T Function(dynamic json) decoder) {
    if (bytes.isEmpty) {
      return decoder(null);
    }

    final String jsonString = utf8.decode(bytes);
    if (jsonString.isEmpty || jsonString == 'null') {
      return decoder(null);
    }

    final dynamic jsonObject = jsonDecode(jsonString);
    return decoder(jsonObject);
  }
}

```
---
## File: lib/src/internal/query_key.dart

```dart
import 'dart:convert';

/// Utilities for generating deterministic cache keys for Axiom queries.
class AxiomQueryKey {
  /// Builds a stable string key for a query based on the endpoint name and arguments.
  static String build({
    required String endpoint,
    required Map<String, dynamic> args,
  }) {
    final normalized = _normalize(args);
    return '$endpoint:${jsonEncode(normalized)}';
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> input) {
    if (input.isEmpty) return const {};

    final sortedKeys = input.keys.toList()..sort();
    final result = <String, dynamic>{};

    for (final key in sortedKeys) {
      final value = input[key];
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }
}

```
---
## File: lib/src/internal/tracing.dart

```dart
import 'dart:math';

/// Generates W3C Trace Context strings.
/// Rust's opentelemetry parses this to link Frontend spans to Backend spans.
class AxiomTracing {
  static final _random = Random.secure();

  /// Returns standard W3C traceparent: 00-[trace_id]-[span_id]-01
  static String generateTraceparent() {
    final traceId = _generateHex(16); // 32 chars
    final spanId = _generateHex(8);   // 16 chars
    return '00-$traceId-$spanId-01';
  }

  static String _generateHex(int bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

```
---
## File: lib/src/mutation.dart

```dart
import 'query.dart';

/// Represents an executable action (POST, PUT, DELETE) generated by the SDK.
///
/// The key difference from AxiomQuery is that mutations are NEVER cached.
/// Each call to [mutationFn] fires a fresh network request regardless of
/// whether the same endpoint was called before. This is required for:
///   - Login / token refresh
///   - Form submissions
///   - Delete or update actions
///
/// The runtime routes these through [AxiomRuntime.sendMutation] which bypasses
/// AxiomQueryManager entirely, so second/third clicks always work correctly.
class AxiomMutation<T, Args> {
  /// The generated SDK method that returns the configured Query.
  /// Always backed by sendMutation — never cached.
  final AxiomQuery<T> Function(Args) mutationFn;

  AxiomMutation(this.mutationFn);
}

```
---
## File: lib/src/query.dart

```dart
import 'dart:async';
import 'package:axiom_flutter/src/runtime_interface.dart';

import 'state.dart';
import 'query_manager.dart';

class AxiomQuery<T> {
  final String key;
  final bool isMutation;

  final Map<String, String> _customHeaders = {};
  Stream<AxiomState<T>>? _cachedStream;

  // The factory returns the wrapper so QueryManager can grab the Request ID
  final AxiomActiveStream<T> Function(Map<String, String> headers)
  _streamFactory;

  AxiomQuery(this.key, this._streamFactory, {this.isMutation = false});

  void setHeader(String key, String value) {
    _customHeaders[key] = value;
  }

  /// The public getter for the UI
  Stream<AxiomState<T>> get stream {
    // ✨ FIX: Extract .stream from the AxiomActiveStream wrapper
    _cachedStream ??= _streamFactory(_customHeaders).stream;
    return _cachedStream!;
  }

  void refresh() {
    if (!isMutation) {
      AxiomQueryManager().invalidate(key);
    }
  }

  Future<void> prefetch() async {
    final subscription = stream.listen(null);
    try {
      await stream.firstWhere((s) => s.hasData || s.hasError);
    } finally {
      subscription.cancel();
    }
  }
}

```
---
## File: lib/src/query_manager.dart

```dart
import 'dart:async';
import 'dart:typed_data';
import 'state.dart';
import 'runtime_interface.dart'; // Import this

class ActiveQuery<T> {
  final String key;
  StreamController<AxiomState<T>>? _controller;
  AxiomState<T> _lastState = AxiomState.loading();
  StreamSubscription? _rustSubscription;
  bool _streamClosed = false;

  // ✨ NEW: Track the active Request ID for WebSockets
  int? currentReqId;

  final AxiomActiveStream<T> Function() _createStream;

  ActiveQuery(this.key, this._createStream) {
    _controller = StreamController<AxiomState<T>>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  Stream<AxiomState<T>> get stream => _controller!.stream;
  AxiomState<T> get state => _lastState;

  void _onListen() {
    if (_rustSubscription == null || _streamClosed) {
      _connect();
    } else {
      _controller?.add(_lastState);
    }
  }

  void _connect() {
    _streamClosed = false;
    _rustSubscription?.cancel();

    // ✨ FIX: Capture the Request ID when the stream is created
    final active = _createStream();
    currentReqId = active.requestId;

    _rustSubscription = active.stream.listen(
      (newState) {
        _lastState = newState;
        if (!(_controller?.isClosed ?? true)) {
          _controller?.add(newState);
        }
      },
      onDone: () {
        // The Rust stream closed (EventType::Complete was received, which the
        // runtime translates to StreamController.close()). Mark the stream as
        // closed so the next subscriber triggers a fresh fetch.
        _streamClosed = true;
      },
      onError: (_) {
        // Dart stream-level errors are not used in this SDK (errors are sent
        // as AxiomState.error() data events), but handle defensively.
        _streamClosed = true;
      },
    );
  }

  void _onCancel() {
    // Keep _rustSubscription alive — cancelling it would abort an in-flight
    // request that may be needed by another subscriber on the broadcast stream.
    // The subscription is only cancelled in refetch() or dispose().
  }

  void refetch() {
    _rustSubscription?.cancel();
    _streamClosed = false;

    if (_lastState.hasData) {
      final refreshingState = AxiomState<T>.success(
        _lastState.data as T,
        _lastState.source,
        isFetching: true,
      );
      _lastState = refreshingState;
      _controller?.add(refreshingState);
    } else {
      final loadingState = AxiomState<T>.loading();
      _lastState = loadingState;
      _controller?.add(loadingState);
    }
    _connect();
  }

  void dispose() {
    _rustSubscription?.cancel();
    _controller?.close();
  }
}

class AxiomQueryManager {
  static final AxiomQueryManager _instance = AxiomQueryManager._();
  factory AxiomQueryManager() => _instance;
  AxiomQueryManager._();

  final Map<String, ActiveQuery> _activeQueries = {};

  Stream<AxiomState<T>> watch<T>(
    String key,
    AxiomActiveStream<T> Function() createFn, // ✨ FIX: Signature
  ) {
    if (_activeQueries.containsKey(key)) {
      final query = _activeQueries[key] as ActiveQuery<T>;
      return query.stream;
    }

    final query = ActiveQuery<T>(key, createFn);
    _activeQueries[key] = query;
    return query.stream;
  }

  // ✨ NEW: Native Send Method
  void send(String key, Uint8List payload, AxiomRuntime runtime) {
    final query = _activeQueries[key];
    if (query != null && query.currentReqId != null) {
      runtime.sendStreamMessage(
        requestId: query.currentReqId!,
        payload: payload,
      );
    } else {
      print('ATMX: Cannot send message, stream not active for $key');
    }
  }

  void invalidate(String key) {
    if (_activeQueries.containsKey(key)) {
      _activeQueries[key]?.refetch();
    }
  }

  /// Removes a key so the next watch() creates a completely fresh ActiveQuery.
  /// Use for mutations that must never share state across calls.
  void remove(String key) {
    _activeQueries.remove(key)?.dispose();
  }

  void clear() {
    for (var q in _activeQueries.values) {
      q.dispose();
    }
    _activeQueries.clear();
  }

  /// Similar to watch, but returns the full AxiomActiveStream wrapper.
  /// Used by the SDK to link the Query object to the Request ID.
  AxiomActiveStream<T> watchRaw<T>(
    String key,
    AxiomActiveStream<T> Function() createFn,
  ) {
    if (_activeQueries.containsKey(key)) {
      final query = _activeQueries[key] as ActiveQuery<T>;
      // Reconstruct wrapper from existing query
      return AxiomActiveStream<T>(query.currentReqId ?? 0, query.stream);
    }

    final query = ActiveQuery<T>(key, createFn);
    _activeQueries[key] = query;

    return AxiomActiveStream<T>(query.currentReqId ?? 0, query.stream);
  }
}

```
---
## File: lib/src/runtime_interface.dart

```dart
import 'dart:typed_data';

import 'state.dart';
import 'query.dart';

import 'runtime_stub.dart'
    if (dart.library.io) 'runtime_io.dart'
    if (dart.library.js_interop) 'runtime_web.dart';

class AxiomStreamResponse {
  final int requestId;
  final Stream<AxiomState<Uint8List>> stream;
  AxiomStreamResponse(this.requestId, this.stream);
}

class AxiomActiveStream<T> {
  final int requestId;
  final Stream<AxiomState<T>> stream;
  AxiomActiveStream(this.requestId, this.stream);
}

abstract class AxiomRuntime {
  factory AxiomRuntime() => getRuntime();

  bool debug = false;

  Future<void> init([String? dbPath]);

  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  });

  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
  });

  AxiomQuery<T> send<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  });

  AxiomQuery<T> sendMutation<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic> args = const {},
    Object? body,
    required T Function(dynamic json) decoder,
  });

  AxiomStreamResponse callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    required Uint8List requestBytes,
  });

  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  });

  void clearAuthToken({required String namespace, required String methodName});

  void sendStreamMessage({required int requestId, required Uint8List payload});
}

class EventType {
  static const int complete = 0;
  static const int networkSuccess = 1;
  static const int cacheHit = 2;
  static const int cacheHitAndFetching = 3;
  static const int error = 4;
  static const int streamChunk = 5;
}

class FfiError {
  static const int successUnverified = -1;
  static const int success = 0;
  static const int unknownError = 1;
  static const int requestParsingFailed = 2;
  static const int networkError = 3;
  static const int responseDeserializationFailed = 4;
  static const int unknownEndpoint = 5;
  static const int timeout = 6;
  static const int requestFailed = 7;
  static const int authError = 8;
  static const int serverError = 9;
  static const int invalidContract = 10;
  static const int runtimeTooOld = 11;
  static const int contractNotLoaded = 12;
  static const int initializationFailed = 13;
  static const int internalError = 14;

  static String name(int code) {
    return switch (code) {
      successUnverified => 'SuccessUnverified',
      success => 'Success',
      unknownError => 'UnknownError',
      requestParsingFailed => 'RequestParsingFailed',
      networkError => 'NetworkError',
      responseDeserializationFailed => 'ResponseDeserializationFailed',
      unknownEndpoint => 'UnknownEndpoint',
      timeout => 'Timeout',
      requestFailed => 'RequestFailed',
      authError => 'AuthError',
      serverError => 'ServerError',
      invalidContract => 'InvalidContract',
      runtimeTooOld => 'RuntimeTooOld',
      contractNotLoaded => 'ContractNotLoaded',
      initializationFailed => 'InitializationFailed',
      internalError => 'InternalError',
      _ => 'UnrecognizedErrorCode',
    };
  }
}

```
---
## File: lib/src/runtime_io.dart

```dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ansicolor/ansicolor.dart';
import 'package:ffi/ffi.dart';

import 'runtime_interface.dart';
import 'state.dart';
import 'query.dart';
import 'query_manager.dart';
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';
import 'internal/tracing.dart';

AxiomRuntime getRuntime() => AxiomRuntimeIo();

base class AxiomString extends Struct {
  external Pointer<Uint8> ptr;
  @Uint64()
  external int len;
}

base class AxiomBuffer extends Struct {
  external Pointer<Uint8> ptr;
  @Uint64()
  external int len;
}

base class AxiomResponseBuffer extends Struct {
  @Uint64()
  external int requestId;
  @Int32()
  external int eventType;
  @Int32()
  external int errorCode;
  external AxiomBuffer data;
  external AxiomBuffer errorMessage;
}

typedef AxiomCallback = Void Function(Pointer<AxiomResponseBuffer> response);
typedef _AxiomInitializeNative = Int32 Function(AxiomString);
typedef _AxiomInitialize = int Function(AxiomString);
typedef _AxiomLoadContractNative =
    Int32 Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
      AxiomString,
    );
typedef _AxiomLoadContract =
    int Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
      AxiomString,
    );
typedef _AxiomRegisterCallbackNative =
    Void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomRegisterCallback =
    void Function(Pointer<NativeFunction<AxiomCallback>>);

// 8 Arguments exactly matching Rust signature
typedef _AxiomCallNative =
    Void Function(
      Uint64,
      AxiomString,
      Uint32,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomBuffer,
    );
typedef _AxiomCall =
    void Function(
      int,
      AxiomString,
      int,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomBuffer,
    );

typedef _AxiomSetAuthTokenNative =
    Void Function(AxiomString, AxiomString, AxiomString);
typedef _AxiomSetAuthToken =
    void Function(AxiomString, AxiomString, AxiomString);
typedef _AxiomClearAuthTokenNative = Void Function(AxiomString, AxiomString);
typedef _AxiomClearAuthToken = void Function(AxiomString, AxiomString);
typedef _AxiomSendStreamMsgNative = Void Function(Uint64, AxiomBuffer);
typedef _AxiomSendStreamMsg = void Function(int, AxiomBuffer);
typedef _AxiomProcessResponsesNative = Void Function();
typedef _AxiomProcessResponses = void Function();
typedef _AxiomFreeResponseBufferNative =
    Void Function(Pointer<AxiomResponseBuffer>);
typedef _AxiomFreeResponseBuffer = void Function(Pointer<AxiomResponseBuffer>);

final _controllers = HashMap<int, StreamController<AxiomState<Uint8List>>>();
final _hadError = HashSet<int>();

int _nextRequestId = 1;
Completer<void>? _initCompleter;
SendPort? _dataPort;
_AxiomFreeResponseBuffer? _freeResponseFfiBackground;

@pragma('vm:entry-point')
void _axiomCallbackHandler(Pointer<AxiomResponseBuffer> responsePtr) {
  if (responsePtr == nullptr) return;
  final response = responsePtr.ref;
  _dataPort?.send([
    response.requestId,
    response.eventType,
    response.errorCode,
    response.data.ptr.address,
    response.data.len,
    response.errorMessage.ptr.address,
    response.errorMessage.len,
  ]);
  _freeResponseFfiBackground?.call(responsePtr);
}

@pragma('vm:entry-point')
void _runRustEventLoop(List<Object> args) {
  final mainIsolateDataPort = args[0] as SendPort;
  final shutdownPort = ReceivePort();
  mainIsolateDataPort.send(shutdownPort.sendPort);
  _dataPort = mainIsolateDataPort;

  final lib = AxiomRuntimeIo._openPlatformLibrary();
  _freeResponseFfiBackground = lib
      .lookupFunction<_AxiomFreeResponseBufferNative, _AxiomFreeResponseBuffer>(
        'axiom_free_response_buffer',
      );
  final registerCallback = lib
      .lookupFunction<_AxiomRegisterCallbackNative, _AxiomRegisterCallback>(
        'axiom_register_callback',
      );
  registerCallback(Pointer.fromFunction(_axiomCallbackHandler));

  final processResponses = lib
      .lookupFunction<_AxiomProcessResponsesNative, _AxiomProcessResponses>(
        'axiom_process_responses',
      );

  shutdownPort.listen((msg) {
    if (msg == 'shutdown') {
      shutdownPort.close();
      Isolate.current.kill();
    }
  });

  while (true) {
    processResponses();
    sleep(const Duration(milliseconds: 5));
  }
}

class AxiomRuntimeIo implements AxiomRuntime {
  static AxiomRuntimeIo? _instance;
  factory AxiomRuntimeIo() => _instance ??= AxiomRuntimeIo._internal();

  static late final DynamicLibrary _lib;
  late final _AxiomInitialize _initFfi;
  late final _AxiomLoadContract _loadContractFfi;
  late final _AxiomCall _callFfi;
  late final _AxiomSetAuthToken _setAuthFfi;
  late final _AxiomClearAuthToken _clearAuthFfi;
  late final _AxiomSendStreamMsg _sendStreamMsgFfi;

  AxiomRuntimeIo._internal() {
    _lib = _openPlatformLibrary();
    _initFfi = _lib.lookupFunction<_AxiomInitializeNative, _AxiomInitialize>(
      'axiom_initialize',
    );
    _loadContractFfi = _lib
        .lookupFunction<_AxiomLoadContractNative, _AxiomLoadContract>(
          'axiom_load_contract',
        );
    _callFfi = _lib.lookupFunction<_AxiomCallNative, _AxiomCall>('axiom_call');
    _setAuthFfi = _lib
        .lookupFunction<_AxiomSetAuthTokenNative, _AxiomSetAuthToken>(
          'axiom_set_auth_token',
        );
    _clearAuthFfi = _lib
        .lookupFunction<_AxiomClearAuthTokenNative, _AxiomClearAuthToken>(
          'axiom_clear_auth_token',
        );
    _sendStreamMsgFfi = _lib
        .lookupFunction<_AxiomSendStreamMsgNative, _AxiomSendStreamMsg>(
          'axiom_send_stream_message',
        );
  }

  @override
  bool debug = false;

  @override
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  }) {
    using((Arena arena) {
      _setAuthFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(methodName, arena),
        _toAxiomString(token, arena),
      );
    });
  }

  @override
  void clearAuthToken({required String namespace, required String methodName}) {
    using((Arena arena) {
      _clearAuthFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(methodName, arena),
      );
    });
  }

  @override
  void sendStreamMessage({required int requestId, required Uint8List payload}) {
    using((Arena arena) {
      final ptr = arena<Uint8>(payload.length);
      ptr.asTypedList(payload.length).setAll(0, payload);
      final buf = arena<AxiomBuffer>()
        ..ref.ptr = ptr
        ..ref.len = payload.length;
      _sendStreamMsgFfi(requestId, buf.ref);
    });
  }

  @override
  Future<void> init([String? dbPath]) async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    final mainIsolatePort = ReceivePort();

    mainIsolatePort.listen((message) {
      if (message is SendPort) {
        _initCompleter!.complete();
        return;
      }

      final int requestId = message[0];
      final int eventTypeValue = message[1];
      final int errorCodeValue = message[2];
      final int dataPtr = message[3];
      final int dataLen = message[4];
      final int errorPtr = message[5];
      final int errorLen = message[6];

      final controller = _controllers[requestId];
      if (controller == null || controller.isClosed) return;

      if (eventTypeValue == EventType.complete) {
        _hadError.remove(requestId);
        controller.close();
        _controllers.remove(requestId);
        return;
      }

      if (eventTypeValue == EventType.streamChunk) {
        final data = Uint8List.fromList(
          Pointer<Uint8>.fromAddress(dataPtr).asTypedList(dataLen),
        );
        controller.add(
          AxiomState.success(data, AxiomSource.network, isStreaming: true),
        );
        return;
      }

      if (eventTypeValue == EventType.error) {
        _hadError.add(requestId);
        AxiomError richError = errorPtr != 0
            ? AxiomError.fromJson(
                jsonDecode(
                  utf8.decode(
                    Pointer<Uint8>.fromAddress(errorPtr).asTypedList(errorLen),
                  ),
                ),
              )
            : AxiomError(
                stage: ErrorStage.runtime,
                category: ErrorCategory.unknown,
                code: UnknownCode(FfiError.name(errorCodeValue)),
                message: 'Internal error',
                retryable: false,
              );
        controller.add(AxiomState.error(richError));
        return;
      }

      if (dataPtr != 0) {
        final data = Uint8List.fromList(
          Pointer<Uint8>.fromAddress(dataPtr).asTypedList(dataLen),
        );
        controller.add(
          AxiomState.success(
            data,
            (eventTypeValue == EventType.cacheHit ||
                    eventTypeValue == EventType.cacheHitAndFetching)
                ? AxiomSource.cache
                : AxiomSource.network,
            isFetching: eventTypeValue == EventType.cacheHitAndFetching,
          ),
        );
      }
    });

    await Isolate.spawn(_runRustEventLoop, [mainIsolatePort.sendPort]);
    using((Arena arena) => _initFfi(_toAxiomString(dbPath ?? '', arena)));
    return _initCompleter!.future;
  }

  @override
  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
  }) {
    using((Arena arena) {
      final cPtr = arena<Uint8>(contractBytes.length);
      cPtr.asTypedList(contractBytes.length).setAll(0, contractBytes);
      final buf = arena<AxiomBuffer>()
        ..ref.ptr = cPtr
        ..ref.len = contractBytes.length;
      _loadContractFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(baseUrl, arena),
        buf.ref,
        _toAxiomString(signature ?? '', arena),
        _toAxiomString(publicKey ?? '', arena),
      );
    });
  }

  @override
  AxiomStreamResponse callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();
    _controllers[requestId] = controller;
    controller.add(AxiomState.loading());

    var finalPath = path;
    pathParams?.forEach(
      (k, v) => finalPath = finalPath.replaceAll('{$k}', v.toString()),
    );

    if (queryParams != null && queryParams.isNotEmpty) {
      final filteredParams = <String, String>{};
      for (final entry in queryParams.entries) {
        if (entry.value != null)
          filteredParams[entry.key] = entry.value.toString();
      }
      if (filteredParams.isNotEmpty) {
        finalPath +=
            (finalPath.contains('?') ? '&' : '?') +
            Uri(queryParameters: filteredParams).query;
      }
    }

    final traceparent = AxiomTracing.generateTraceparent();
    final headersJson = headers != null && headers.isNotEmpty
        ? jsonEncode(headers)
        : '';

    _logTransaction('OUT', requestId, {
      'ns': namespace,
      'ep': endpointId,
      'm': method,
      'p': finalPath,
    });

    final arena = Arena();
    final bPtr = arena<Uint8>(requestBytes.length);
    bPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
    final b = arena<AxiomBuffer>()
      ..ref.ptr = bPtr
      ..ref.len = requestBytes.length;

    _callFfi(
      requestId,
      _toAxiomString(namespace, arena),
      endpointId,
      _toAxiomString(method, arena),
      _toAxiomString(finalPath, arena),
      _toAxiomString(traceparent, arena),
      _toAxiomString(headersJson, arena), // Passed to Native Rust successfully
      b.ref,
    );
    Future.microtask(() => arena.releaseAll());

    controller.onCancel = () => _controllers.remove(requestId);
    return AxiomStreamResponse(requestId, controller.stream);
  }

  @override
  AxiomQuery<T> send<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    final key = AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
    );

    // ✨ FIX: Return AxiomActiveStream by calling the QueryManager's new wrapper logic
    return AxiomQuery(key, (customHeaders) {
      final mergedHeaders = {...?headers, ...customHeaders};

      // We wrap the rawStream in a new AxiomActiveStream for AxiomQuery
      return AxiomQueryManager().watchRaw<T>(
        key,
        () => _rawStream(
          namespace: namespace,
          endpointId: endpointId,
          method: method,
          path: path,
          headers: mergedHeaders,
          pathParams: pathParams,
          queryParams: queryParams,
          body: body,
          decoder: decoder,
        ),
      );
    });
  }

  @override
  AxiomQuery<T> sendMutation<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic> args = const {},
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    final key =
        '${namespace}_${endpointId}_mut_${DateTime.now().microsecondsSinceEpoch}';

    return AxiomQuery(key, (customHeaders) {
      final mergedHeaders = {...?headers, ...customHeaders};
      return _rawStream(
        namespace: namespace,
        endpointId: endpointId,
        method: method,
        path: path,
        headers: mergedHeaders,
        pathParams: pathParams,
        queryParams: queryParams,
        body: body,
        decoder: decoder,
      );
    }, isMutation: true);
  }

  AxiomActiveStream<T> _rawStream<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    final response = callStream(
      namespace: namespace,
      endpointId: endpointId,
      method: method,
      path: path,
      headers: headers,
      pathParams: pathParams,
      queryParams: queryParams,
      requestBytes: AxiomCodec.encodeBody(body, headers),
    );

    final mappedStream = response.stream.map((state) {
      if (state.hasError) return state.map((_) => null as T);
      if (state.data != null) {
        try {
          return AxiomState<T>.success(
            AxiomCodec.decode(state.data!, decoder),
            state.source,
            isFetching: state.isFetching,
            isStreaming: state.isStreaming,
          );
        } catch (e) {
          return AxiomState<T>.error(
            AxiomError(
              stage: ErrorStage.deserialize,
              category: ErrorCategory.serialization,
              code: const CodecError(),
              message: e.toString(),
              retryable: false,
            ),
          );
        }
      }
      return state.map((_) => null as T);
    });

    return AxiomActiveStream<T>(response.requestId, mappedStream);
  }

  AxiomString _toAxiomString(String s, Arena arena) {
    final units = utf8.encode(s);
    final ptr = arena<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    return arena<AxiomString>().ref
      ..ptr = ptr
      ..len = units.length;
  }

  void _logTransaction(String dir, int id, dynamic details) {
    if (!debug) return;
    final pen = AnsiPen()
      ..white(bold: true)
      ..xterm(dir == 'OUT' ? 063 : 034);
    print(pen('${dir == 'OUT' ? '➔ CALL' : '← RESP'} [#$id] $details'));
  }

  static DynamicLibrary _openPlatformLibrary() =>
      Platform.isIOS || Platform.isMacOS
      ? DynamicLibrary.process()
      : DynamicLibrary.open('libaxiom_runtime.so');

  @override
  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  }) async {
    await init(dbPath);
    loadContract(
      namespace: 'default',
      baseUrl: baseUrl,
      contractBytes: contractBytes,
      signature: signature,
      publicKey: publicKey,
    );
  }
}

```
---
## File: lib/src/runtime_stub.dart

```dart
import 'runtime_interface.dart';

AxiomRuntime getRuntime() =>
    throw UnsupportedError('Cannot create AxiomRuntime on this platform.');

```
---
## File: lib/src/runtime_web.dart

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

import 'runtime_interface.dart';
import 'state.dart';
import 'query.dart';
import 'query_manager.dart';
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';
import 'internal/tracing.dart';

AxiomRuntime getRuntime() => AxiomRuntimeWeb();

@JS('wasm_bindgen')
external JSPromise _wasmBindgenInit(JSAny moduleOrPath);

@JS()
@staticInterop
class WasmExports {}

extension WasmExportsExt on WasmExports {
  @JS('axiom_wasm_initialize')
  external int axiomInitialize(int dbPtr, int dbLen);

  @JS('axiom_wasm_load_contract')
  external int axiomLoadContract(
    int nPtr,
    int nLen,
    int bPtr,
    int bLen,
    int cPtr,
    int cLen,
    int sPtr,
    int sLen,
    int pkPtr,
    int pkLen,
  );

  @JS('axiom_wasm_call')
  external void axiomCall(
    JSNumber reqId,
    int nPtr,
    int nLen,
    int epId,
    int mPtr,
    int mLen,
    int pPtr,
    int pLen,
    int tpPtr,
    int tpLen,
    int hPtr,
    int hLen, // <-- Headers
    int bPtr,
    int bLen, // <-- Payload
  );

  @JS('axiom_wasm_set_auth_token')
  external void axiomSetAuthToken(
    int nPtr,
    int nLen,
    int mPtr,
    int mLen,
    int tPtr,
    int tLen,
  );

  @JS('axiom_wasm_clear_auth_token')
  external void axiomClearAuthToken(int nPtr, int nLen, int mPtr, int mLen);

  @JS('axiom_wasm_send_stream_message')
  external void axiomSendMsg(JSNumber reqId, int ptr, int len);

  @JS('axiom_malloc')
  external int axiomMalloc(int size);

  @JS('axiom_free_memory')
  external void axiomFreeMemory(int ptr, int size);

  @JS('axiom_process_responses')
  external void axiomProcessResponses();

  @JS('memory')
  external WasmMemory get memory;
}

@JS()
@staticInterop
class WasmMemory {}

extension WasmMemoryExt on WasmMemory {
  @JS('buffer')
  external JSArrayBuffer get jsBuffer;
}

class AxiomRuntimeWeb implements AxiomRuntime {
  static AxiomRuntimeWeb? _instance;
  factory AxiomRuntimeWeb() => _instance ??= AxiomRuntimeWeb._internal();
  AxiomRuntimeWeb._internal();

  final _controllers = <int, StreamController<AxiomState<Uint8List>>>{};
  final _hadError = <int>{};
  int _nextRequestId = 1;
  late final WasmExports _wasm;

  @override
  bool debug = false;

  @override
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  }) {
    final n = _alloc(namespace), m = _alloc(methodName), t = _alloc(token);
    _wasm.axiomSetAuthToken(n.ptr, n.len, m.ptr, m.len, t.ptr, t.len);
    _free(n);
    _free(m);
    _free(t);
  }

  @override
  void clearAuthToken({required String namespace, required String methodName}) {
    final n = _alloc(namespace), m = _alloc(methodName);
    _wasm.axiomClearAuthToken(n.ptr, n.len, m.ptr, m.len);
    _free(n);
    _free(m);
  }

  @override
  void sendStreamMessage({required int requestId, required Uint8List payload}) {
    final b = _allocBytes(payload);
    _wasm.axiomSendMsg(requestId.toJS, b.ptr, b.len);
    _free(b);
  }

  @override
  Future<void> init([String? dbPath]) async {
    if (globalContext.has('wasm_bindgen')) return;
    final jsCode = await rootBundle.loadString(
      'packages/axiom_flutter/lib/assets/wasm/axiom_runtime.js',
    );
    final script = web.HTMLScriptElement()
      ..type = 'application/javascript'
      ..text = '$jsCode\nwindow.wasm_bindgen = wasm_bindgen;';
    web.document.head!.appendChild(script);

    final wasmData = await rootBundle.load(
      'packages/axiom_flutter/lib/assets/wasm/axiom_runtime_bg.wasm',
    );
    _wasm =
        (await _wasmBindgenInit(wasmData.buffer.toJS).toDart) as WasmExports;
    _setupWebCallback();
    Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _wasm.axiomProcessResponses(),
    );

    final db = _alloc(dbPath ?? '');
    _wasm.axiomInitialize(db.ptr, db.len);
    _free(db);
  }

  void _setupWebCallback() {
    globalContext['axiom_web_callback'] =
        ((
              JSNumber reqId,
              JSNumber evtType,
              JSNumber errCode,
              JSNumber dPtr,
              JSNumber dLen,
              JSNumber ePtr,
              JSNumber eLen,
            ) {
              final id = reqId.toDartInt;
              final controller = _controllers[id];
              if (controller == null) return;

              if (evtType.toDartInt == EventType.complete) {
                _hadError.remove(id);
                if (!controller.isClosed) controller.close();
                _controllers.remove(id);
                return;
              }

              if (evtType.toDartInt == EventType.streamChunk) {
                Uint8List data = Uint8List.fromList(
                  Uint8List.view(
                    _wasm.memory.jsBuffer.toDart,
                    dPtr.toDartInt,
                    dLen.toDartInt,
                  ),
                );
                controller.add(
                  AxiomState.success(
                    data,
                    AxiomSource.network,
                    isStreaming: true,
                  ),
                );
                return;
              }

              if (evtType.toDartInt == EventType.error) {
                _hadError.add(id);
                String errJson = '';
                if (ePtr.toDartInt != 0) {
                  errJson = utf8.decode(
                    Uint8List.view(
                      _wasm.memory.jsBuffer.toDart,
                      ePtr.toDartInt,
                      eLen.toDartInt,
                    ),
                  );
                }
                final error = errJson.isNotEmpty
                    ? AxiomError.fromJson(jsonDecode(errJson))
                    : AxiomError(
                        stage: ErrorStage.runtime,
                        category: ErrorCategory.unknown,
                        code: UnknownCode(FfiError.name(errCode.toDartInt)),
                        message: 'Internal error',
                        retryable: false,
                      );
                controller.add(AxiomState.error(error));
                return;
              }

              if (dPtr.toDartInt != 0) {
                final data = Uint8List.fromList(
                  Uint8List.view(
                    _wasm.memory.jsBuffer.toDart,
                    dPtr.toDartInt,
                    dLen.toDartInt,
                  ),
                );
                controller.add(
                  AxiomState.success(
                    data,
                    (evtType.toDartInt == EventType.cacheHit ||
                            evtType.toDartInt == EventType.cacheHitAndFetching)
                        ? AxiomSource.cache
                        : AxiomSource.network,
                    isFetching:
                        evtType.toDartInt == EventType.cacheHitAndFetching,
                  ),
                );
              }
            })
            .toJS;
  }

  @override
  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
  }) {
    final n = _alloc(namespace),
        b = _alloc(baseUrl),
        c = _allocBytes(contractBytes);
    final s = _alloc(signature ?? ''), p = _alloc(publicKey ?? '');
    _wasm.axiomLoadContract(
      n.ptr,
      n.len,
      b.ptr,
      b.len,
      c.ptr,
      c.len,
      s.ptr,
      s.len,
      p.ptr,
      p.len,
    );
    _free(n);
    _free(b);
    _free(c);
    _free(s);
    _free(p);
  }

  @override
  AxiomStreamResponse callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    required Uint8List requestBytes,
  }) {
    final id = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();
    _controllers[id] = controller;
    controller.add(AxiomState.loading());

    var fPath = path;
    pathParams?.forEach(
      (k, v) => fPath = fPath.replaceAll('{$k}', v.toString()),
    );

    if (queryParams != null && queryParams.isNotEmpty) {
      final filteredParams = <String, String>{};
      for (final entry in queryParams.entries) {
        if (entry.value != null)
          filteredParams[entry.key] = entry.value.toString();
      }
      if (filteredParams.isNotEmpty) {
        fPath +=
            (fPath.contains('?') ? '&' : '?') +
            Uri(queryParameters: filteredParams).query;
      }
    }

    final tp = AxiomTracing.generateTraceparent();
    final hStr = headers != null && headers.isNotEmpty
        ? jsonEncode(headers)
        : '';

    final n = _alloc(namespace),
        m = _alloc(method),
        p = _alloc(fPath),
        t = _alloc(tp),
        h = _alloc(hStr);
    final br = _allocBytes(requestBytes);

    _wasm.axiomCall(
      id.toJS,
      n.ptr,
      n.len,
      endpointId,
      m.ptr,
      m.len,
      p.ptr,
      p.len,
      t.ptr,
      t.len,
      h.ptr,
      h.len, // Passed to Wasm Rust successfully
      br.ptr,
      br.len,
    );

    _free(n);
    _free(m);
    _free(p);
    _free(t);
    _free(h);
    _free(br);
    return AxiomStreamResponse(id, controller.stream);
  }

  @override
  AxiomQuery<T> send<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    final key = AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
    );

    // ✨ FIX: Return AxiomActiveStream by calling the QueryManager's new wrapper logic
    return AxiomQuery(key, (customHeaders) {
      final mergedHeaders = {...?headers, ...customHeaders};

      // We wrap the rawStream in a new AxiomActiveStream for AxiomQuery
      return AxiomQueryManager().watchRaw<T>(
        key,
        () => _rawStream(
          namespace: namespace,
          endpointId: endpointId,
          method: method,
          path: path,
          headers: mergedHeaders,
          pathParams: pathParams,
          queryParams: queryParams,
          body: body,
          decoder: decoder,
        ),
      );
    });
  }

  @override
  AxiomQuery<T> sendMutation<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic> args = const {},
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    final key =
        '${namespace}_${endpointId}_mut_${DateTime.now().microsecondsSinceEpoch}';
    return AxiomQuery(key, (customHeaders) {
      final mergedHeaders = {...?headers, ...customHeaders};
      return _rawStream(
        namespace: namespace,
        endpointId: endpointId,
        method: method,
        path: path,
        headers: mergedHeaders,
        pathParams: pathParams,
        queryParams: queryParams,
        body: body,
        decoder: decoder,
      );
    }, isMutation: true);
  }

  AxiomActiveStream<T> _rawStream<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    final response = callStream(
      namespace: namespace,
      endpointId: endpointId,
      method: method,
      path: path,
      headers: headers,
      pathParams: pathParams,
      queryParams: queryParams,
      requestBytes: AxiomCodec.encodeBody(body, headers),
    );

    final mappedStream = response.stream.map((state) {
      if (state.hasError) return state.map((_) => null as T);
      if (state.data != null) {
        try {
          return AxiomState<T>.success(
            AxiomCodec.decode(state.data!, decoder),
            state.source,
            isFetching: state.isFetching,
            isStreaming: state.isStreaming,
          );
        } catch (e) {
          return AxiomState<T>.error(
            AxiomError(
              stage: ErrorStage.deserialize,
              category: ErrorCategory.serialization,
              code: const CodecError(),
              message: e.toString(),
              retryable: false,
            ),
          );
        }
      }
      return state.map((_) => null as T);
    });

    return AxiomActiveStream<T>(response.requestId, mappedStream);
  }

  _WebAlloc _alloc(String s) => _allocBytes(Uint8List.fromList(utf8.encode(s)));
  _WebAlloc _allocBytes(Uint8List b) {
    final ptr = _wasm.axiomMalloc(b.length);
    Uint8List.view(_wasm.memory.jsBuffer.toDart, ptr, b.length).setAll(0, b);
    return _WebAlloc(ptr, b.length);
  }

  void _free(_WebAlloc a) => _wasm.axiomFreeMemory(a.ptr, a.len);

  @override
  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  }) async {
    await init(dbPath);
    loadContract(
      namespace: 'default',
      baseUrl: baseUrl,
      contractBytes: contractBytes,
      signature: signature,
      publicKey: publicKey,
    );
  }
}

class _WebAlloc {
  final int ptr, len;
  _WebAlloc(this.ptr, this.len);
}

```
---
## File: lib/src/state.dart

```dart
enum ErrorStage {
  configuration,
  contractLoad,
  requestBuild,
  validationRequest,
  cacheRead,
  networkSend,
  networkReceive,
  validationResponse,
  deserialize,
  cacheWrite,
  runtime,
  ffiBoundary;

  static ErrorStage fromString(String val) => ErrorStage.values.firstWhere(
    (e) => e.name.toLowerCase() == val.toLowerCase(),
    orElse: () => ErrorStage.runtime,
  );
}

enum ErrorCategory {
  contract,
  validation,
  network,
  timeout,
  serialization,
  cache,
  auth,
  server,
  runtime,
  unknown;

  static ErrorCategory fromString(String val) =>
      ErrorCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == val.toLowerCase(),
        orElse: () => ErrorCategory.unknown,
      );
}

sealed class AxiomErrorCode {
  const AxiomErrorCode();

  factory AxiomErrorCode.fromJson(dynamic json) {
    if (json is String) {
      return switch (json) {
        'ContractMissing' => const ContractMissing(),
        'ContractInvalid' => const ContractInvalid(),
        'EndpointNotFound' => const EndpointNotFound(),
        'ValidationError' => const ValidationError(),
        'NetworkTimeout' => const NetworkTimeout(),
        'NetworkConnectionFailed' => const NetworkConnectionFailed(),
        'JsonParseError' => const JsonParseError(),
        'CodecError' => const CodecError(),
        'AuthTokenExpired' => const AuthTokenExpired(),
        'NotInitialized' => const NotInitialized(),
        _ => UnknownCode(json),
      };
    } else if (json is Map && json.containsKey('HttpStatus')) {
      return HttpStatus(json['HttpStatus'] as int);
    }
    return UnknownCode(json.toString());
  }
}

class ContractMissing extends AxiomErrorCode {
  const ContractMissing();
}

class ContractInvalid extends AxiomErrorCode {
  const ContractInvalid();
}

class EndpointNotFound extends AxiomErrorCode {
  const EndpointNotFound();
}

class ValidationError extends AxiomErrorCode {
  const ValidationError();
}

class NetworkTimeout extends AxiomErrorCode {
  const NetworkTimeout();
}

class NetworkConnectionFailed extends AxiomErrorCode {
  const NetworkConnectionFailed();
}

class JsonParseError extends AxiomErrorCode {
  const JsonParseError();
}

class CodecError extends AxiomErrorCode {
  const CodecError();
}

class AuthTokenExpired extends AxiomErrorCode {
  const AuthTokenExpired();
}

class NotInitialized extends AxiomErrorCode {
  const NotInitialized();
}

class HttpStatus extends AxiomErrorCode {
  final int code;
  const HttpStatus(this.code);
}

class UnknownCode extends AxiomErrorCode {
  final String raw;
  const UnknownCode(this.raw);
}

/// The main rich error object that is deserialized from Rust.
// FILE: lib/src/state.dart (Partial Replacement)

class AxiomError {
  final ErrorStage stage;
  final ErrorCategory category;
  final AxiomErrorCode code;
  final String message;
  final bool retryable;
  final String? details;

  AxiomError({
    required this.stage,
    required this.category,
    required this.code,
    required this.message,
    required this.retryable,
    this.details,
  });

  factory AxiomError.fromJson(Map<String, dynamic> json) {
    return AxiomError(
      stage: ErrorStage.fromString(json['stage']),
      category: ErrorCategory.fromString(json['category']),
      code: AxiomErrorCode.fromJson(json['code']),
      message: json['message'],
      retryable: json['retryable'] ?? false,
      details: json['details'],
    );
  }

  /// NEW: The Magic Zero-Dart Validation Parser
  /// Extracts field-specific errors from the Rust rod-rs schema validator.
  String? getFieldError(String fieldName) {
    if (code is! ValidationError || details == null) return null;

    // Rust rod-rs formats errors as: "path.to.field: Error message\nanother.field: Error message"
    final lines = details!.split('\n');
    for (final line in lines) {
      if (line.startsWith('$fieldName:')) {
        return line.substring(fieldName.length + 1).trim();
      }
    }
    return null;
  }

  @override
  String toString() => '[$stage::$category] $message (Code: $code)';
}

enum AxiomStatus { idle, loading, success, error } // Added 'idle'

enum AxiomSource { none, cache, network }

class AxiomState<T> {
  final AxiomStatus status;
  final T? data;
  final AxiomError? error;
  final AxiomSource source;
  final bool isFetching;
  final bool isMutating;
  final bool isStreaming;

  const AxiomState({
    required this.status,
    this.data,
    this.error,
    this.source = AxiomSource.none,
    this.isFetching = false,
    this.isMutating = false,
    this.isStreaming = false,
  });

  AxiomState<R> map<R>(R Function(T data) mapper) {
    return AxiomState<R>(
      status: status,
      data: data != null ? mapper(data!) : null,
      error: error,
      source: source,
      isFetching: isFetching,
      isMutating: isMutating,
      isStreaming: isStreaming,
    );
  }

  factory AxiomState.idle() => const AxiomState(status: AxiomStatus.idle);

  factory AxiomState.loading() =>
      const AxiomState(status: AxiomStatus.loading, isFetching: true);

  factory AxiomState.mutating() =>
      const AxiomState(status: AxiomStatus.loading, isMutating: true);

  factory AxiomState.success(
    T data,
    AxiomSource source, {
    bool isFetching = false,
    bool isStreaming = false,
  }) => AxiomState(
    status: AxiomStatus.success,
    data: data,
    source: source,
    isFetching: isFetching,
    isStreaming: isStreaming,
  );

  factory AxiomState.error(
    AxiomError error, {
    T? previousData,
    AxiomSource? previousSource,
  }) => AxiomState(
    status: AxiomStatus.error,
    error: error,
    data: previousData,
    source: previousSource ?? AxiomSource.none,
  );

  bool get isIdle => status == AxiomStatus.idle;
  bool get isLoading => status == AxiomStatus.loading;
  bool get isSuccess => status == AxiomStatus.success;
  bool get hasError => status == AxiomStatus.error;
  bool get hasData => data != null;
}

```
---
## File: lib/src/widgets/axiom_builder.dart

```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../state.dart';
import '../query.dart';

typedef AxiomDataWidgetBuilder<R> =
    Widget Function(BuildContext context, AxiomState<R> state, R data);

typedef AxiomErrorWidgetBuilder =
    Widget Function(BuildContext context, AxiomError error);

typedef AxiomLoadingWidgetBuilder = Widget Function(BuildContext context);

/// A powerful builder that handles Axiom query state, data transformation, and build optimization.
///
/// [T] is the raw type coming from the SDK (e.g. models.User).
/// [R] is the transformed type used in the UI (e.g. String). Defaults to [T].
class AxiomBuilder<T, R> extends StatefulWidget {
  final AxiomQuery<T> query;

  /// Optional: Transform the data before it reaches the builder or selector.
  /// If null, [T] is cast to [R].
  final R Function(T data)? transform;

  /// Optional: Select specific fields to determine when to rebuild.
  /// If the selected value hasn't changed (compared via deep equality),
  /// the [builder] is NOT called, saving performance.
  ///
  /// Example: `selector: (user) => [user.name, user.role]`
  final Object? Function(R data)? selector;

  final AxiomDataWidgetBuilder<R> builder;
  final AxiomErrorWidgetBuilder? error;
  final AxiomLoadingWidgetBuilder? loading;

  const AxiomBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.transform,
    this.selector,
    this.error,
    this.loading,
  });

  @override
  State<AxiomBuilder<T, R>> createState() => _AxiomBuilderState<T, R>();
}

class _AxiomBuilderState<T, R> extends State<AxiomBuilder<T, R>> {
  StreamSubscription<AxiomState<T>>? _subscription;
  AxiomState<R>? _currentState;
  Object? _previousSelection;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant AxiomBuilder<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.key != widget.query.key) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.query.stream.listen((rawState) {
      final AxiomState<R> newState;

      if (rawState.data != null) {
        if (widget.transform != null) {
          final transformedData = widget.transform!(rawState.data as T);
          newState = AxiomState.success(
            transformedData,
            rawState.source,
            isFetching: rawState.isFetching,
          );
        } else {
          newState = AxiomState.success(
            rawState.data as R,
            rawState.source,
            isFetching: rawState.isFetching,
          );
        }
      } else if (rawState.hasError) {
        newState = AxiomState.error(
          rawState.error!,
          previousData: _currentState?.data,
          previousSource: _currentState?.source,
        );
      } else {
        newState = AxiomState.loading();
      }

      if (widget.selector != null && newState.data != null) {
        final newSelection = widget.selector!(newState.data as R);

        if (_currentState?.data != null &&
            _deepEquals(_previousSelection, newSelection)) {
          if (_currentState?.isFetching == newState.isFetching) {
            _currentState = newState;
            return;
          }
        }
        _previousSelection = newSelection;
      }

      if (mounted) {
        setState(() {
          _currentState = newState;
        });
      }
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
    _previousSelection = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _currentState;

    if (state == null || (state.isLoading && state.data == null)) {
      return widget.loading?.call(context) ?? const SizedBox.shrink();
    }

    if (state.hasError && state.data == null) {
      if (widget.error != null) {
        return widget.error!(context, state.error!);
      }
      return Center(child: Text('Error: ${state.error}'));
    }

    return widget.builder(context, state, state.data as R);
  }

  bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }
}

```
---
## File: lib/src/widgets/axiom_mutation_builder.dart

```dart
// FILE: lib/src/widgets/axiom_mutation_builder.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../state.dart';
import '../mutation.dart';

typedef AxiomMutationWidgetBuilder<T, Args> =
    Widget Function(
      BuildContext context,
      AxiomState<T> state,
      void Function(Args args) execute,
    );

/// A reactive builder for Form Submissions and Mutations (POST, PUT, DELETE).
class AxiomMutationBuilder<T, Args> extends StatefulWidget {
  final AxiomMutation<T, Args> mutation;
  final AxiomMutationWidgetBuilder<T, Args> builder;

  const AxiomMutationBuilder({
    super.key,
    required this.mutation,
    required this.builder,
  });

  @override
  State<AxiomMutationBuilder<T, Args>> createState() =>
      _AxiomMutationBuilderState<T, Args>();
}

class _AxiomMutationBuilderState<T, Args>
    extends State<AxiomMutationBuilder<T, Args>> {
  AxiomState<T> _state = AxiomState.idle();
  StreamSubscription<AxiomState<T>>? _subscription;

  void _execute(Args args) {
    if (!mounted) return;

    // Switch UI to mutating state
    setState(() {
      _state = AxiomState.mutating();
    });

    _subscription?.cancel();

    // Execute the SDK query (triggers Wasm Engine immediately)
    final query = widget.mutation.mutationFn(args);

    _subscription = query.stream.listen((newState) {
      if (mounted) {
        setState(() {
          // Keep isMutating true until success or error
          if (newState.isLoading) {
            _state = AxiomState.mutating();
          } else {
            _state = AxiomState(
              status: newState.status,
              data: newState.data,
              error: newState.error,
              source: newState.source,
              isFetching: false,
              isMutating: false, // Execution finished!
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _state, _execute);
  }
}

```
---
## File: pubspec.yaml

```yaml
name: axiom_flutter
description: "Axiom Flutter SDK"
version: 0.107.0
homepage: https://github.com/AxiomCore/axiom-sdk
repository: https://github.com/AxiomCore/axiom-sdk
issue_tracker: https://github.com/AxiomCore/axiom-sdk/issues

environment:
  sdk: ^3.8.0
  flutter: ">=1.17.0"

dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.4
  path_provider: ^2.1.5
  ansicolor: ^2.0.3
  web: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec

# The following section is specific to Flutter packages.
flutter:
  plugin:
    platforms:
      ios:
        pluginClass: AxiomFlutterPlugin
      macos:
        pluginClass: AxiomFlutterPlugin

  # ADD THIS SECTION: Bundle Wasm files with the Web build
  assets:
    - lib/assets/wasm/axiom_runtime.js
    - lib/assets/wasm/axiom_runtime_bg.wasm

```
---
