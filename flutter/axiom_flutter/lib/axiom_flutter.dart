library axiom_flutter;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
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
  late final DynamicLibrary _lib;
  late final AxiomCall _call;
  late final AxiomInitialize _init;
  late final AxiomFreeBuffer _free;

  AxiomRuntime() {
    _lib = _openPlatformLibrary();

    _call = _lib.lookupFunction<NativeAxiomCall, AxiomCall>('axiom_call');
    _init = _lib.lookupFunction<NativeAxiomInitialize, AxiomInitialize>(
      'axiom_initialize',
    );
    _free = _lib.lookupFunction<NativeAxiomFreeBuffer, AxiomFreeBuffer>(
      'axiom_free_buffer',
    );
  }

  static DynamicLibrary _openPlatformLibrary() {
    if (Platform.isAndroid) {
      // Flutter bundles this automatically in android/src/main/jniLibs/
      return DynamicLibrary.open('libaxiom_generated_runtime.so');
    }

    if (Platform.isIOS) {
      // iOS bundles dylibs automatically in the Framework
      return DynamicLibrary.process(); // <- iOS loads from main bundle
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

    throw UnsupportedError("Unsupported platform for AxiomRuntime");
  }

  /// Call Rust: axiom_initialize(AxiomString { ptr, len })
  void initialize(String baseUrl) {
    final units = Uint8List.fromList(baseUrl.codeUnits);
    final ptr = malloc<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);

    final axStrPtr = malloc<AxiomString>();
    axStrPtr.ref
      ..ptr = ptr
      ..len = units.length;

    _init(axStrPtr.ref);

    // We own this memory on the Dart side, so we free it.
    malloc.free(ptr);
    malloc.free(axStrPtr);
  }

  /// Generic call() method (FlatBuffers request → bytes → FBS decode by caller)
  Future<Uint8List> call({
    required int endpointId,
    required Uint8List requestBytes,
  }) async {
    // Allocate and fill input bytes
    final inPtr = malloc<Uint8>(requestBytes.length);
    inPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);

    // Wrap into AxiomBuffer struct
    final inBufPtr = malloc<AxiomBuffer>();
    inBufPtr.ref
      ..ptr = inPtr
      ..len = requestBytes.length;

    // Output buffer will be filled by Rust
    final outBufPtr = malloc<AxiomBuffer>();

    final res = _call(endpointId, inBufPtr.ref, outBufPtr);

    // We no longer need the input AxiomBuffer wrapper (but still own inPtr)
    malloc.free(inBufPtr);

    if (res != 0) {
      // Clean up our allocations
      malloc.free(outBufPtr);
      malloc.free(inPtr);
      throw Exception('FFI call failed with code $res');
    }

    // Copy data out of Rust-owned buffer
    final outBuf = outBufPtr.ref;
    final outLen = outBuf.len;
    final outData = outBuf.ptr.asTypedList(outLen);
    final copied = Uint8List.fromList(outData);

    // Ask Rust to free the buffer it allocated
    _free(outBuf);

    // Free our wrapper + input pointer
    malloc.free(outBufPtr);
    malloc.free(inPtr);

    return copied;
  }
}
