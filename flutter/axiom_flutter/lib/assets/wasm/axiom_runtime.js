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
            __wbg_fetch_8d9b732df7467c44: function(arg0) {
                const ret = fetch(getObject(arg0));
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
            __wbg_instanceof_Error_6872d63ba7922898: function(arg0) {
                let result;
                try {
                    result = getObject(arg0) instanceof Error;
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
            __wbg_message_cb4f84ee66e5e341: function(arg0) {
                const ret = getObject(arg0).message;
                return addHeapObject(ret);
            },
            __wbg_msCrypto_bd5a034af96bcba6: function(arg0) {
                const ret = getObject(arg0).msCrypto;
                return addHeapObject(ret);
            },
            __wbg_name_d3c35622d14bb080: function(arg0) {
                const ret = getObject(arg0).name;
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
            __wbg_new_4331d3ba658c037d: function() { return handleError(function () {
                const ret = new URLSearchParams();
                return addHeapObject(ret);
            }, arguments); },
            __wbg_new_490db15a0a09fb24: function() { return handleError(function (arg0, arg1) {
                const ret = new URL(getStringFromWasm0(arg0, arg1));
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
            __wbg_new_with_str_5f3ca98523ee76ef: function() { return handleError(function (arg0, arg1) {
                const ret = new Request(getStringFromWasm0(arg0, arg1));
                return addHeapObject(ret);
            }, arguments); },
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
            __wbg_search_98479a9dd6b1643e: function(arg0, arg1) {
                const ret = getObject(arg1).search;
                const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_export, wasm.__wbindgen_export2);
                const len1 = WASM_VECTOR_LEN;
                getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
                getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
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
            __wbg_set_1ffc463d4c541483: function() { return handleError(function (arg0, arg1, arg2, arg3, arg4) {
                getObject(arg0).set(getStringFromWasm0(arg1, arg2), getStringFromWasm0(arg3, arg4));
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
            __wbg_set_search_2982fabf5212b32d: function(arg0, arg1, arg2) {
                getObject(arg0).search = getStringFromWasm0(arg1, arg2);
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
            __wbg_toString_306ed0b9f320c1ca: function(arg0) {
                const ret = getObject(arg0).toString();
                return addHeapObject(ret);
            },
            __wbg_toString_6dc1a94e0bdba378: function(arg0) {
                const ret = getObject(arg0).toString();
                return addHeapObject(ret);
            },
            __wbg_url_2bf741820e6563a0: function(arg0, arg1) {
                const ret = getObject(arg1).url;
                const ptr1 = passStringToWasm0(ret, wasm.__wbindgen_export, wasm.__wbindgen_export2);
                const len1 = WASM_VECTOR_LEN;
                getDataViewMemory0().setInt32(arg0 + 4 * 1, len1, true);
                getDataViewMemory0().setInt32(arg0 + 4 * 0, ptr1, true);
            },
            __wbg_url_94ef047be3ab790a: function(arg0, arg1) {
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
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [Externref], shim_idx: 194, ret: Result(Unit), inner_ret: Some(Result(Unit)) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_2515);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000002: function(arg0, arg1) {
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [NamedExternref("Event")], shim_idx: 62, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_2347);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000003: function(arg0, arg1) {
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [NamedExternref("MessageEvent")], shim_idx: 62, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_2347_2);
                return addHeapObject(ret);
            },
            __wbindgen_cast_0000000000000004: function(arg0, arg1) {
                // Cast intrinsic for `Closure(Closure { owned: true, function: Function { arguments: [], shim_idx: 111, ret: Unit, inner_ret: Some(Unit) }, mutable: true }) -> Externref`.
                const ret = makeMutClosure(arg0, arg1, __wasm_bindgen_func_elem_2354);
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

    function __wasm_bindgen_func_elem_2354(arg0, arg1) {
        wasm.__wasm_bindgen_func_elem_2354(arg0, arg1);
    }

    function __wasm_bindgen_func_elem_2347(arg0, arg1, arg2) {
        wasm.__wasm_bindgen_func_elem_2347(arg0, arg1, addHeapObject(arg2));
    }

    function __wasm_bindgen_func_elem_2347_2(arg0, arg1, arg2) {
        wasm.__wasm_bindgen_func_elem_2347_2(arg0, arg1, addHeapObject(arg2));
    }

    function __wasm_bindgen_func_elem_2515(arg0, arg1, arg2) {
        try {
            const retptr = wasm.__wbindgen_add_to_stack_pointer(-16);
            wasm.__wasm_bindgen_func_elem_2515(retptr, arg0, arg1, addHeapObject(arg2));
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
