library axiom_flutter;

import 'dart:ffi';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';

/// Must match Rust:
/// #[repr(C)]
/// pub struct AxiomString { pub ptr: *const u8, pub len: usize }
base class AxiomString extends Struct {
  external Pointer<Uint8> ptr;

  @Uint64()
  external int len;
}

/// Must match Rust:
/// #[repr(C)]
/// pub struct AxiomBuffer { pub ptr: *mut u8, pub len: usize }
base class AxiomBuffer extends Struct {
  external Pointer<Uint8> ptr;

  @Uint64()
  external int len;
}

/// Rust:
/// pub extern "C" fn axiom_initialize(base_url: AxiomString)
typedef NativeAxiomInitialize = Void Function(AxiomString);
typedef AxiomInitialize = void Function(AxiomString);

/// Rust:
/// pub extern "C" fn axiom_call(
///   endpoint_id: u32,
///   input_buf: AxiomBuffer,
///   output_buf: *mut AxiomBuffer,
/// ) -> FfiResult   // repr(C) enum => i32
typedef NativeAxiomCall =
    Int32 Function(
      Uint32 endpointId,
      AxiomBuffer input,
      Pointer<AxiomBuffer> output,
    );
typedef AxiomCall =
    int Function(
      int endpointId,
      AxiomBuffer input,
      Pointer<AxiomBuffer> output,
    );

/// Rust:
/// pub extern "C" fn axiom_free_buffer(buf: AxiomBuffer)
typedef NativeAxiomFreeBuffer = Void Function(AxiomBuffer);
typedef AxiomFreeBuffer = void Function(AxiomBuffer);

class AxiomRuntime {
  static const _channel = MethodChannel("axiom_runtime_channel");

  late final DynamicLibrary _ffiLib;
  late final bool _useMethodChannel;

  AxiomRuntime() {
    _useMethodChannel = Platform.isIOS;

    if (!_useMethodChannel) {
      _ffiLib = _loadFfiLibrary();
    }
  }

  DynamicLibrary _loadFfiLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libaxiom_generated_runtime.so');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libaxiom_generated_runtime.dylib');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libaxiom_generated_runtime.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('axiom_generated_runtime.dll');
    }
    throw UnsupportedError("Unsupported platform");
  }

  Future<void> initialize(String baseUrl) async {
    if (_useMethodChannel) {
      return _channel.invokeMethod("initialize", {"baseUrl": baseUrl});
    }

    // FFI path (unchanged)
    final units = Uint8List.fromList(baseUrl.codeUnits);
    final ptr = malloc<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);

    final axStrPtr = malloc<AxiomString>()
      ..ref.ptr = ptr
      ..ref.len = units.length;

    final initFn = _ffiLib
        .lookupFunction<NativeAxiomInitialize, AxiomInitialize>(
          'axiom_initialize',
        );
    initFn(axStrPtr.ref);

    malloc.free(ptr);
    malloc.free(axStrPtr);
  }

  Future<Uint8List> call({
    required int endpointId,
    required Uint8List requestBytes,
  }) async {
    if (_useMethodChannel) {
      final out = await _channel.invokeMethod("call", {
        "endpointId": endpointId,
        "input": requestBytes,
      });

      return out.bytes;
    }

    // FFI path (unchanged)
    final inPtr = malloc<Uint8>(requestBytes.length);
    inPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);

    final inBufPtr = malloc<AxiomBuffer>()
      ..ref.ptr = inPtr
      ..ref.len = requestBytes.length;

    final outBufPtr = malloc<AxiomBuffer>();

    final callFn = _ffiLib.lookupFunction<NativeAxiomCall, AxiomCall>(
      'axiom_call',
    );

    final code = callFn(endpointId, inBufPtr.ref, outBufPtr);
    malloc.free(inBufPtr);

    if (code != 0) {
      malloc.free(outBufPtr);
      malloc.free(inPtr);
      throw Exception("FFI call failed: $code");
    }

    final outBytes = Uint8List.fromList(
      outBufPtr.ref.ptr!.asTypedList(outBufPtr.ref.len),
    );

    final freeFn = _ffiLib
        .lookupFunction<NativeAxiomFreeBuffer, AxiomFreeBuffer>(
          'axiom_free_buffer',
        );
    freeFn(outBufPtr.ref);

    malloc.free(outBufPtr);
    malloc.free(inPtr);

    return outBytes;
  }
}
