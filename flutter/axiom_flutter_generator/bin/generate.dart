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

  final modelsFile = File('${libOutDir.path}/models.dart');
  final modelsBuffer = StringBuffer();
  _writeModelsFile(modelsBuffer, ir, packageName, outDir);
  modelsFile.writeAsStringSync(modelsBuffer.toString());
  stdout.writeln('✅ Successfully wrote ${modelsFile.path}');

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
  final modelsImportPath = outDir.isEmpty
      ? 'models.dart'
      : '$outDir/models.dart';

  // schema import via package:<appName>/...
  buffer.writeln("import 'package:$packageName/$schemaImportPath' as schema;");
  buffer.writeln("import 'package:$packageName/$modelsImportPath' as models;");
  buffer.writeln();

  // Class header
  buffer.writeln('class AxiomSdk {');
  buffer.writeln('  final AxiomRuntime _runtime;');
  buffer.writeln();
  buffer.writeln('  // Private constructor to ensure proper initialization.');
  buffer.writeln('  AxiomSdk._(this._runtime);');
  buffer.writeln();
  buffer.writeln('  /// Asynchronously creates and initializes the Axiom SDK.');
  buffer.writeln(
    '  static Future<AxiomSdk> create({required String baseUrl}) async {',
  );
  buffer.writeln('    // Get the singleton instance of the runtime.');
  buffer.writeln('    final runtime = AxiomRuntime();');
  buffer.writeln('    // Ensure the background isolate is running and ready.');
  buffer.writeln('    await runtime.init();');
  buffer.writeln('    // Set the base URL for the runtime.');
  buffer.writeln('    runtime.initialize(baseUrl);');
  buffer.writeln('    // Return the fully initialized SDK.');
  buffer.writeln('    return AxiomSdk._(runtime);');
  buffer.writeln('  }');
  buffer.writeln();

  // 7) Endpoints
  final endpoints = (ir['endpoints'] as List?) ?? const [];
  for (final ep in endpoints) {
    if (ep is Map<String, dynamic>) {
      _writeEndpointMethod(
        buffer,
        ep,
        ir,
        (ir['models'] as Map).cast<String, dynamic>(),
      );
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
  const runtimeSource = r'''
// GENERATED – DO NOT EDIT.
// Low-level FFI bridge to AxiomRuntime (Rust) for this project only.

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// --- FFI Structs and Enums (must match Rust) ---

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

enum FfiError {
  success,
  unknownError,
  requestParsingFailed,
  networkError,
  responseDeserializationFailed,
  unknownEndpoint,
}

base class AxiomResponseBuffer extends Struct {
  @Uint64() external int requestId;
  @Int32() external int errorCode; // Use Int32 for enums
  external AxiomBuffer data;
}

// --- FFI Function Signatures ---
typedef AxiomCallback = Void Function(AxiomResponseBuffer response);
typedef _AxiomInitializeNative = Void Function(AxiomString);
typedef _AxiomInitialize = void Function(AxiomString);
typedef _AxiomRegisterCallbackNative = Void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomRegisterCallback = void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomCallNative = Void Function(Uint64, Uint32, AxiomBuffer);
typedef _AxiomCall = void Function(int, int, AxiomBuffer);
typedef _AxiomFreeBufferNative = Void Function(AxiomBuffer);
typedef _AxiomFreeBuffer = void Function(AxiomBuffer);
typedef _AxiomProcessResponsesNative = Void Function();
typedef _AxiomProcessResponses = void Function();


// --- Global state for managing async callbacks ---
final _completers = HashMap<int, Completer<Uint8List>>();
int _nextRequestId = 1;
SendPort? _commandPort;
Completer<void>? _initCompleter;
SendPort? _dataPort;

@pragma('vm:entry-point')
void _axiomCallbackHandler(AxiomResponseBuffer response) {
  _dataPort?.send([
    response.requestId,
    response.errorCode, // Now sending the integer error code
    response.data.ptr.address,
    response.data.len
  ]);
}

@pragma('vm:entry-point')
void _runRustEventLoop(List<Object> args) {
  final mainIsolateDataPort = args[0] as SendPort;
  final shutdownPort = ReceivePort();
  mainIsolateDataPort.send(shutdownPort.sendPort);
  _dataPort = mainIsolateDataPort;
  
  final lib = AxiomRuntime._openPlatformLibrary();
  final registerCallback = lib.lookupFunction<_AxiomRegisterCallbackNative, _AxiomRegisterCallback>('axiom_register_callback');
  registerCallback(Pointer.fromFunction(_axiomCallbackHandler));
  final processResponses = lib.lookupFunction<_AxiomProcessResponsesNative, _AxiomProcessResponses>('axiom_process_responses');

  shutdownPort.listen((msg) {
    if (msg == 'shutdown') {
      shutdownPort.close();
      Isolate.current.kill();
    }
  });

  while (true) {
    processResponses();
  }
}

class AxiomRuntime {
  static AxiomRuntime? _instance;
  factory AxiomRuntime() {
    _instance ??= AxiomRuntime._internal();
    return _instance!;
  }

  ReceivePort? _mainIsolatePort;

  static Future<void> dispose() async {
    if (_instance != null) {
      final completer = Completer<void>();
      _instance!._mainIsolatePort?.listen(null, onDone: () {
        if (!completer.isCompleted) completer.complete();
      });
      _commandPort?.send('shutdown');
      _instance!._mainIsolatePort?.close();
      _completers.clear();
      _instance = null;
      _commandPort = null;
      _initCompleter = null;
      await completer.future.timeout(const Duration(milliseconds: 200), onTimeout: () {});
    }
  }

  static late final DynamicLibrary _lib;
  late final _AxiomInitialize _initFfi;
  late final _AxiomCall _callFfi;
  static late final _AxiomFreeBuffer _freeFfi;

  AxiomRuntime._internal() {
    _lib = _openPlatformLibrary();
    _initFfi = _lib.lookupFunction<_AxiomInitializeNative, _AxiomInitialize>('axiom_initialize');
    _callFfi = _lib.lookupFunction<_AxiomCallNative, _AxiomCall>('axiom_call');
    _freeFfi = _lib.lookupFunction<_AxiomFreeBufferNative, _AxiomFreeBuffer>('axiom_free_buffer');
  }

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    _mainIsolatePort = ReceivePort();

    _mainIsolatePort!.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        if (!_initCompleter!.isCompleted) _initCompleter!.complete();
        return;
      }
      
      final int requestId = message[0];
      final int errorCodeValue = message[1];
      final int ptrAddress = message[2];
      final int len = message[3];

      final completer = _completers.remove(requestId);
      if (completer == null) {
        if (ptrAddress != 0) {
            final buffer = calloc<AxiomBuffer>();
            buffer.ref.ptr = Pointer.fromAddress(ptrAddress);
            buffer.ref.len = len;
            _freeFfi(buffer.ref);
            calloc.free(buffer);
        }
        return;
      }

      if (errorCodeValue == FfiError.success.index && ptrAddress != 0) {
        final ptr = Pointer<Uint8>.fromAddress(ptrAddress);
        final data = Uint8List.fromList(ptr.asTypedList(len));
        completer.complete(data);
        
        final buffer = calloc<AxiomBuffer>();
        buffer.ref.ptr = ptr;
        buffer.ref.len = len;
        _freeFfi(buffer.ref);
        calloc.free(buffer);
      } else {
        // Map the integer error code back to the enum for a clear error message.
        final error = FfiError.values[errorCodeValue];
        completer.completeError(Exception('Axiom FFI call failed for request #$requestId with error: ${error.name}'));
      }
    });

    await Isolate.spawn(_runRustEventLoop, [_mainIsolatePort!.sendPort]);
    return _initCompleter!.future;
  }
  
  static DynamicLibrary _openPlatformLibrary() {
    if (Platform.isIOS) { return DynamicLibrary.process(); }
    throw UnsupportedError('AxiomRuntime is only available on iOS in this build');
  }

  void initialize(String baseUrl) {
    final units = Uint8List.fromList(baseUrl.codeUnits);
    final ptr = malloc<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    final axStrPtr = malloc<AxiomString>();
    axStrPtr.ref..ptr = ptr..len = units.length;
    _initFfi(axStrPtr.ref);
    malloc.free(ptr);
    malloc.free(axStrPtr);
  }

  Future<Uint8List> call({
    required int endpointId,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;
    final completer = Completer<Uint8List>();
    _completers[requestId] = completer;

    final inPtr = malloc<Uint8>(requestBytes.length);
    inPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
    final inBufPtr = malloc<AxiomBuffer>();
    inBufPtr.ref..ptr = inPtr..len = requestBytes.length;

    try {
      _callFfi(requestId, endpointId, inBufPtr.ref);
    } catch (e) {
      _completers.remove(requestId);
      completer.completeError(e);
    } finally {
      malloc.free(inPtr);
      malloc.free(inBufPtr);
    }

    return completer.future;
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
  Map<String, dynamic> allModels,
) {
  final rawName = ep['name'] as String? ?? 'endpoint';
  final fnName = _camelCase(rawName);
  final epId = ep['id'] ?? 0;
  final path = ep['path'] as String? ?? '';
  final returnTypeRef = (ep['returnType'] as Map).cast<String, dynamic>();
  final responseShape = _classifyReturnType(returnTypeRef);

  final params = (ep['parameters'] as List?) ?? const [];
  final paramDecls = <String>[];
  final paramInfos = <Map<String, dynamic>>[];

  for (final p in params) {
    if (p is! Map) continue;
    final param = p.cast<String, dynamic>();
    final name = param['name'] as String? ?? 'arg';
    final camelName = _camelCase(name);
    final typeRef = (param['typeRef'] as Map).cast<String, dynamic>();
    // --- FIX #3 HERE ---
    // Use the model-aware type mapper for user-facing types
    final dartType = _dartModelTypeForTypeRef(typeRef, allModels);
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

  String dartReturnType;
  switch (responseShape.kind) {
    case _ResponseKind.model:
      dartReturnType = 'models.${_pascalCase(responseShape.modelName ?? '')}';
      break;
    case _ResponseKind.modelVec:
      dartReturnType =
          'List<models.${_pascalCase(responseShape.modelName ?? '')}>';
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

  final reqType = '${_pascalCase(rawName)}RequestObjectBuilder';
  buffer.writeln('    final requestBytes = schema.$reqType(');

  for (final p in paramInfos) {
    final camel = p['camelName'];
    final t = p['typeRef'] as Map<String, dynamic>;
    final kind = t['kind'] as String;

    // --- FIX #2 HERE ---
    // Use the camelCase name for the ObjectBuilder property
    final builderParamName = _camelCase(p['origName']);

    if (kind == 'named') {
      final modelName = _pascalCase(t['value']);
      final obName = 'schema.${modelName}ObjectBuilder';
      buffer.writeln('      $builderParamName: $obName(');

      final modelDef = allModels[t['value']] as Map<String, dynamic>;
      final fields = (modelDef['fields'] as List);
      for (final f in fields) {
        final fieldName = f['name'];
        // The properties of the ObjectBuilder also need to be camelCase
        final builderFieldName = _camelCase(fieldName);
        final modelFieldName = _camelCase(fieldName);
        buffer.writeln('        $builderFieldName: $camel.$modelFieldName,');
      }
      buffer.writeln('      ),');
    } else {
      buffer.writeln('      $builderParamName: $camel,');
    }
  }
  buffer.writeln('    ).toBytes();');

  buffer.writeln('    final responseBytes = await _runtime.call(');
  buffer.writeln('      endpointId: $epId,');
  buffer.writeln('      requestBytes: requestBytes,');
  buffer.writeln('    );');

  final respType = '${_pascalCase(rawName)}Response';
  switch (responseShape.kind) {
    case _ResponseKind.model:
      final modelName = _pascalCase(responseShape.modelName!);
      buffer.writeln('    final resp = schema.$respType(responseBytes);');
      buffer.writeln('    final schemaValue = resp.data;');
      buffer.writeln(
        '    if (schemaValue == null) { throw StateError("$respType.data was null"); }',
      );
      buffer.writeln('    return models.$modelName.fromSchema(schemaValue);');
      break;

    case _ResponseKind.modelVec:
      final modelName = _pascalCase(responseShape.modelName!);
      buffer.writeln('    final resp = schema.$respType(responseBytes);');
      buffer.writeln('    final schemaItems = resp.data;');
      buffer.writeln(
        '    if (schemaItems == null) return <models.$modelName>[];',
      );
      buffer.writeln(
        '    return schemaItems.map((e) => models.$modelName.fromSchema(e)).toList();',
      );
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

void _writeModelsFile(
  StringBuffer buffer,
  Map<String, dynamic> ir,
  String packageName,
  String outDir,
) {
  buffer.writeln('// GENERATED CODE – DO NOT EDIT.');
  buffer.writeln('// User-facing data models.');
  buffer.writeln();

  final schemaImportPath = outDir.isEmpty
      ? 'schema_axiom_generated.dart'
      : '$outDir/schema_axiom_generated.dart';
  buffer.writeln("import 'package:$packageName/$schemaImportPath' as schema;");
  buffer.writeln();

  final models = (ir['models'] as Map?)?.cast<String, dynamic>() ?? {};

  for (final modelDef in models.values) {
    if (modelDef is! Map<String, dynamic>) continue;

    final modelName = _pascalCase(modelDef['name']);
    buffer.writeln('class $modelName {');

    final fields = (modelDef['fields'] as List?) ?? [];

    // Generate final properties
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final fieldName = _camelCase(field['name']);
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final isOptional = field['isOptional'] as bool? ?? true;
      String dartType = _dartModelTypeForTypeRef(
        typeRef,
        models,
      ); // Use a new type mapper
      if (isOptional) dartType += '?';

      buffer.writeln('  final $dartType $fieldName;');
    }
    buffer.writeln();

    // Generate the constructor
    buffer.writeln('  const $modelName({');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final fieldName = _camelCase(field['name']);
      final isOptional = field['isOptional'] as bool? ?? true;
      if (!isOptional) {
        buffer.writeln('    required this.$fieldName,');
      } else {
        buffer.writeln('    this.$fieldName,');
      }
    }
    buffer.writeln('  });');
    buffer.writeln();

    // Generate a `fromSchema` factory constructor
    buffer.writeln(
      '  factory $modelName.fromSchema(schema.$modelName schemaModel) {',
    );
    buffer.writeln('    return $modelName(');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final origName = field['name'];
      final camelName = _camelCase(origName);
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final kind = typeRef['kind'] as String;
      final isOptional = field['isOptional'] as bool? ?? false;
      final bang = isOptional ? '' : '!'; // <-- FIX #1 HERE

      // Handle nested models and lists of models
      if (kind == 'named') {
        final nestedModelName = _pascalCase(typeRef['value']);
        if (isOptional) {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName != null ? models.$nestedModelName.fromSchema(schemaModel.$camelName!) : null,',
          );
        } else {
          buffer.writeln(
            '      $camelName: models.$nestedModelName.fromSchema(schemaModel.$camelName!),',
          );
        }
      } else if (kind == 'list' &&
          (typeRef['value'] as Map)['kind'] == 'named') {
        final innerModelName = _pascalCase((typeRef['value'] as Map)['value']);
        if (isOptional) {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName?.map((e) => models.$innerModelName.fromSchema(e)).toList(),',
          );
        } else {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName!.map((e) => models.$innerModelName.fromSchema(e)).toList(),',
          );
        }
      } else {
        buffer.writeln('      $camelName: schemaModel.$camelName$bang,');
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln('}');
    buffer.writeln();
  }
}

// Add this new type mapper for the model layer
String _dartModelTypeForTypeRef(
  Map<String, dynamic> t,
  Map<String, dynamic> allModels,
) {
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
    case 'named':
      // This is the key change: prefix with 'models.'
      return 'models.${_pascalCase(t['value'] as String)}';
    case 'list':
      final innerType = (t['value'] as Map).cast<String, dynamic>();
      // Recursively call to handle nested types like List<models.User>
      return 'List<${_dartModelTypeForTypeRef(innerType, allModels)}>';
    case 'json':
      return 'Map<String, dynamic>';
    case 'map':
      // Simplified for now, as complex map keys/values are often handled as JSON.
      return 'Map<String, dynamic>';
    case 'void':
      return 'void';
    default:
      return 'dynamic';
  }
}
