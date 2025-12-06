#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

/// --------------------------
/// Constants (must match Rust)
/// --------------------------
const _magicBytes = [0x41, 0x58, 0x4f, 0x4d]; // "AXOM"
const int _formatVersion = 1;
const String _obfuscationKey = 'AxiomCoreSecretKey2025!';

/// TOC entry from .axiom file.
class _TocEntry {
  final String name;
  final int offset;
  final int size;
  _TocEntry(this.name, this.offset, this.size);
}

/// For classifying endpoint return shapes.
enum _ResponseKind { model, modelVec, json }

class _ResponseShape {
  final _ResponseKind kind;
  final String? modelName; // for model / modelVec
  const _ResponseShape(this.kind, [this.modelName]);

  factory _ResponseShape.model(String model) =>
      _ResponseShape(_ResponseKind.model, model);

  factory _ResponseShape.modelVec(String model) =>
      _ResponseShape(_ResponseKind.modelVec, model);

  factory _ResponseShape.json() => const _ResponseShape(_ResponseKind.json);
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('axiom', help: 'Path to the .axiom file')
    ..addOption(
      'out',
      help: 'Output path relative to lib/ where axiom_sdk.dart will be written',
    )
    ..addOption(
      'project-root',
      help: 'Path to the Flutter project root containing pubspec.yaml',
    )
    ..addFlag('help', negatable: false);

  final results = parser.parse(args);

  if (results['help'] == true) {
    print(parser.usage);
    exit(0);
  }

  final axiomPath = results['axiom'] as String?;
  final outDir = results['out'] as String?;
  final projectRoot = results['project-root'] as String?;

  if (axiomPath == null || outDir == null || projectRoot == null) {
    stderr.writeln(
      '❌ Missing required arguments. You must provide --axiom, --out and --project-root.',
    );
    stderr.writeln(parser.usage);
    exit(1);
  }

  try {
    await _generateSdk(
      axiomPath: axiomPath,
      outDirRelToLib: outDir,
      projectRoot: projectRoot,
    );
  } catch (e, st) {
    stderr.writeln('❌ Failed to generate Axiom SDK: $e');
    stderr.writeln(st);
    exit(1);
  }
}

/// Main generator entry.
Future<void> _generateSdk({
  required String axiomPath,
  required String outDirRelToLib,
  required String projectRoot,
}) async {
  // 1) Decode IR from .axiom
  final ir = await _loadIrFromAxiom(axiomPath);

  final serviceName = (ir['serviceName'] as String?) ?? '';

  // 2) Compute normalized output dir (relative to lib/)
  final outDir = _normalizeOutDir(outDirRelToLib);

  // 3) Determine Dart package name from pubspec.yaml
  final packageName = _readPubspecName(projectRoot);

  // 4) Prepare output directory under lib/
  final libOutDir = Directory('$projectRoot/lib/$outDir');
  if (!libOutDir.existsSync()) {
    libOutDir.createSync(recursive: true);
  }

  // 4a) Write local runtime bridge: axiom_runtime.dart (NEW)
  await _writeRuntimeBridge(libOutDir);

  // 5) Compute target file path for SDK
  final sdkFile = File('${libOutDir.path}/axiom_sdk.dart');

  // 6) Build Dart source for SDK
  final buffer = StringBuffer();

  buffer.writeln('// GENERATED CODE – DO NOT EDIT.');
  buffer.writeln('// Axiom SDK for $serviceName');
  buffer.writeln();

  // Local runtime bridge instead of package:axiom_flutter
  buffer.writeln("import 'axiom_runtime.dart';");

  final schemaImportPath = outDir.isEmpty
      ? 'schema_axiom_generated.dart'
      : '$outDir/schema_axiom_generated.dart';

  // schema import via package:<appName>/...
  buffer.writeln("import 'package:$packageName/$schemaImportPath' as schema;");
  buffer.writeln();

  // Class header
  buffer.writeln('class AxiomSdk {');
  buffer.writeln('  final AxiomRuntime _runtime;');
  buffer.writeln('  AxiomSdk({required String baseUrl})');
  buffer.writeln('    : _runtime = AxiomRuntime() {');
  buffer.writeln('    _runtime.initialize(baseUrl);');
  buffer.writeln('  }');
  buffer.writeln();

  // 7) Endpoints
  final endpoints = (ir['endpoints'] as List?) ?? const [];
  for (final ep in endpoints) {
    if (ep is Map<String, dynamic>) {
      _writeEndpointMethod(buffer, ep, ir);
      buffer.writeln();
    }
  }

  buffer.writeln('}');

  // 8) Write axiom_sdk.dart
  sdkFile.writeAsStringSync(buffer.toString());
  stdout.writeln('✅ Successfully wrote ${sdkFile.path}');
}

/// -------------------------------
/// Write local runtime bridge
/// -------------------------------

Future<void> _writeRuntimeBridge(Directory libOutDir) async {
  final runtimeFile = File('${libOutDir.path}/axiom_runtime.dart');

  // This is essentially the old axiom_flutter runtime, but local and iOS-only
  const runtimeSource = r'''
// GENERATED – DO NOT EDIT.
// Low-level FFI bridge to AxiomRuntime (Rust) for this project only.

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
typedef NativeAxiomCall = Int32 Function(
  Uint32 endpointId,
  AxiomBuffer input,
  Pointer<AxiomBuffer> output,
);
typedef AxiomCall = int Function(
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
    if (Platform.isIOS) {
      // AxiomRuntime is linked into the main app binary via Pod 'AxiomRuntime'
      return DynamicLibrary.process();
    }

    // For now, only iOS is wired up. Others can be added later.
    throw UnsupportedError('AxiomRuntime is only available on iOS in this build');
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
''';

  runtimeFile.writeAsStringSync(runtimeSource);
  stdout.writeln('✅ Wrote ${runtimeFile.path}');
}

/// -------------------------------
/// .axiom decoding helpers
/// -------------------------------

Future<Map<String, dynamic>> _loadIrFromAxiom(String axiomPath) async {
  final file = File(axiomPath);
  if (!file.existsSync()) {
    throw Exception('Axiom file not found: $axiomPath');
  }

  final blob = await file.readAsBytes();
  if (blob.length < 16) {
    throw Exception('File too small to be valid .axiom');
  }

  final bd = ByteData.sublistView(blob);

  // Magic
  for (int i = 0; i < 4; i++) {
    if (blob[i] != _magicBytes[i]) {
      throw Exception('Invalid magic bytes in .axiom file');
    }
  }

  final version = bd.getUint32(4, Endian.little);
  if (version != _formatVersion) {
    throw Exception('Unsupported .axiom format version: $version');
  }

  final tocLen = bd.getUint64(8, Endian.little);
  const headerSize = 4 + 4 + 8;
  final tocStart = headerSize;
  final tocEnd = tocStart + tocLen;

  if (tocEnd > blob.length) {
    throw Exception('TOC length exceeds file size');
  }

  final tocBytes = Uint8List.sublistView(blob, tocStart, tocEnd.toInt());
  final tocEntries = _parseBincodeToc(tocBytes);

  final irEntry = tocEntries
      .where((e) => e.name == 'ir.json')
      .cast<_TocEntry?>()
      .firstWhere((e) => e != null, orElse: () => null);

  if (irEntry == null) {
    throw Exception('ir.json entry not found in .axiom TOC');
  }

  final start = irEntry.offset;
  final end = irEntry.offset + irEntry.size;
  if (end > blob.length) {
    throw Exception('ir.json entry exceeds file size');
  }

  final enc = Uint8List.sublistView(blob, start, end);
  final dec = Uint8List.fromList(enc);
  _xorCipher(dec);

  final jsonStr = utf8.decode(dec);
  final decoded = jsonDecode(jsonStr);
  if (decoded is! Map<String, dynamic>) {
    throw Exception('IR JSON did not decode to an object');
  }
  return decoded;
}

List<_TocEntry> _parseBincodeToc(Uint8List data) {
  final bd = ByteData.sublistView(data);
  int pos = 0;

  int readU64() {
    final value = bd.getUint64(pos, Endian.little);
    pos += 8;
    return value;
  }

  final vecLen = readU64();
  final entries = <_TocEntry>[];

  for (int i = 0; i < vecLen; i++) {
    final nameLen = readU64();
    final nameEnd = pos + nameLen;
    if (nameEnd > data.length) {
      throw Exception('Invalid TOC: name length out of range');
    }
    final nameBytes = data.sublist(pos, nameEnd);
    pos = nameEnd;
    final name = utf8.decode(nameBytes);

    final offset = readU64();
    final size = readU64();

    entries.add(_TocEntry(name, offset, size));
  }

  return entries;
}

void _xorCipher(Uint8List data) {
  final key = utf8.encode(_obfuscationKey);
  for (var i = 0; i < data.length; i++) {
    data[i] = data[i] ^ key[i % key.length];
  }
}

/// -------------------------------
/// Pubspec / path helpers
/// -------------------------------

String _readPubspecName(String projectRoot) {
  final pubspec = File('$projectRoot/pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw Exception('pubspec.yaml not found at $projectRoot/pubspec.yaml');
  }
  final content = pubspec.readAsStringSync();
  final doc = loadYaml(content);
  final name = (doc as YamlMap?)?['name'];
  if (name is! String) {
    throw Exception('Could not find a valid "name" in pubspec.yaml');
  }
  return name.trim();
}

/// Normalize output dir (strip leading/trailing slashes, optional "lib/")
String _normalizeOutDir(String outDir) {
  var d = outDir.trim();
  if (d.startsWith('lib/')) {
    d = d.substring(4);
  }
  d = d.replaceAll(RegExp(r'^/+'), '');
  d = d.replaceAll(RegExp(r'/+$'), '');
  return d;
}

/// -------------------------------
/// Naming helpers
/// -------------------------------

String _pascalCase(String name) {
  if (name.isEmpty) return name;
  final parts = name
      .split(RegExp(r'[_\-\s]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return name[0].toUpperCase() + name.substring(1);

  final buf = StringBuffer();
  for (final part in parts) {
    if (part.isEmpty) continue;
    buf.write(part[0].toUpperCase());
    if (part.length > 1) {
      buf.write(part.substring(1));
    }
  }
  return buf.toString();
}

String _camelCase(String name) {
  if (name.isEmpty) return name;
  final pascal = _pascalCase(name);
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// -------------------------------
/// Type & endpoint helpers
/// -------------------------------

String _dartParamTypeForTypeRef(Map<String, dynamic> t) {
  final kind = t['kind'] as String;

  switch (kind) {
    case 'int32':
    case 'int64':
      return 'int';
    case 'float32':
    case 'float64':
      return 'double';
    case 'bool':
      return 'bool';
    case 'string':
    case 'dateTime':
      return 'String';
    case 'bytes':
      return 'Uint8List';

    // NEW: named model → schema.Model
    case 'named':
      final model = t['value'] as String;
      return 'schema.${_pascalCase(model)}';

    case 'json':
      return 'Map<String, dynamic>';
    case 'map':
      return 'Map<String, dynamic>';
    case 'list':
      return 'List<dynamic>';
    case 'void':
      return 'void';
    default:
      return 'dynamic';
  }
}

_ResponseShape _classifyReturnType(Map<String, dynamic> t) {
  final kind = t['kind'] as String;
  final value = t['value'];

  if (kind == 'named' && value is String) {
    return _ResponseShape.model(value);
  }

  if (kind == 'list' && value is Map<String, dynamic>) {
    final innerKind = value['kind'] as String?;
    final innerVal = value['value'];
    if (innerKind == 'named' && innerVal is String) {
      return _ResponseShape.modelVec(innerVal);
    }
  }

  // Fallback: generic JSON
  return _ResponseShape.json();
}

/// Generate a single endpoint method into [buffer].
void _writeEndpointMethod(
  StringBuffer buffer,
  Map<String, dynamic> ep,
  Map<String, dynamic> ir,
) {
  final rawName = ep['name'] as String? ?? 'endpoint';
  final fnName = _camelCase(rawName);
  final epId = ep['id'] ?? 0;
  final path = ep['path'] as String? ?? '';
  final returnTypeRef = (ep['returnType'] as Map).cast<String, dynamic>();
  final responseShape = _classifyReturnType(returnTypeRef);

  // Parameters
  final params = (ep['parameters'] as List?) ?? const [];
  final paramDecls = <String>[];
  final paramInfos = <Map<String, dynamic>>[];

  for (final p in params) {
    if (p is! Map) continue;
    final param = p.cast<String, dynamic>();
    final name = param['name'] as String? ?? 'arg';
    final camelName = _camelCase(name);
    final typeRef = (param['typeRef'] as Map).cast<String, dynamic>();
    final dartType = _dartParamTypeForTypeRef(typeRef);
    final isOptional = param['isOptional'] as bool? ?? false;

    paramDecls.add(
      isOptional ? '$dartType? $camelName' : 'required $dartType $camelName',
    );

    paramInfos.add({
      'origName': name,
      'camelName': camelName,
      'typeRef': typeRef,
      'isOptional': isOptional,
    });
  }

  // Return type
  String dartReturnType;
  switch (responseShape.kind) {
    case _ResponseKind.model:
      dartReturnType = 'schema.${_pascalCase(responseShape.modelName ?? '')}';
      break;
    case _ResponseKind.modelVec:
      dartReturnType =
          'List<schema.${_pascalCase(responseShape.modelName ?? '')}>';
      break;
    default:
      dartReturnType = 'dynamic';
  }

  buffer.writeln('  /// Endpoint "$rawName"');
  buffer.writeln('  /// Path: $path');
  buffer.writeln('  /// IR endpoint id: $epId');
  buffer.writeln(
    '  Future<$dartReturnType> $fnName({${paramDecls.join(', ')}}) async {',
  );

  // === Correct request building using ObjectBuilder ===
  final reqType = '${_pascalCase(rawName)}RequestObjectBuilder';

  buffer.writeln('    final requestBytes = schema.$reqType(');

  // Write each param into the constructor
  for (final p in paramInfos) {
    final camel = p['camelName'];
    final t = p['typeRef'] as Map<String, dynamic>;
    final kind = t['kind'] as String;

    if (kind == 'named') {
      final modelName = _pascalCase(t['value']);
      final obName = 'schema.${modelName}ObjectBuilder';

      buffer.writeln('      $camel: $obName(');

      // Auto-expand all fields of the model
      final models = ir['models'] as Map<String, dynamic>;
      final fields = (models[t['value']]['fields'] as List);

      for (final f in fields) {
        final fieldName = f['name'];
        final camelField = _camelCase(fieldName);
        buffer.writeln('        $fieldName: $camel.$camelField,');
      }

      buffer.writeln('      ),');
    } else {
      buffer.writeln('      $camel: $camel,');
    }
  }

  buffer.writeln('    ).toBytes();');

  buffer.writeln('    final responseBytes = await _runtime.call(');
  buffer.writeln('      endpointId: $epId,');
  buffer.writeln('      requestBytes: requestBytes,');
  buffer.writeln('    );');

  // === Decode response ===
  final respType = '${_pascalCase(rawName)}Response';

  switch (responseShape.kind) {
    case _ResponseKind.model:
      buffer.writeln('    final resp = schema.$respType(responseBytes);');
      buffer.writeln('    final value = resp.data;');
      buffer.writeln(
        '    if (value == null) { throw StateError("$respType.data was null"); }',
      );
      buffer.writeln('    return value;');
      break;

    case _ResponseKind.modelVec:
      final modelName = _pascalCase(responseShape.modelName!);
      buffer.writeln('    final resp = schema.$respType(responseBytes);');
      buffer.writeln('    final items = resp.data;');
      buffer.writeln('    if (items == null) return <schema.$modelName>[];');
      buffer.writeln('    return List<schema.$modelName>.unmodifiable(items);');
      break;

    case _ResponseKind.json:
      buffer.writeln('    final resp = schema.$respType(responseBytes);');
      buffer.writeln('    final jsonStr = resp.json;');
      buffer.writeln('    if (jsonStr == null) return null;');
      buffer.writeln('    return jsonDecode(jsonStr);');
      break;
  }

  buffer.writeln('  }');
}
