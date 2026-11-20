import 'schema.dart';
import 'types.dart';
import 'utils.dart';

/// Per-contract inputs from AxiomDeps.toml / CLI flags.
class ContractInput {
  final String namespace;
  final Map<String, dynamic> contract;

  /// Null when neither the contract nor the pull config names one.
  final String? baseUrl;
  final String assetPath;
  final String? signature;
  final String? publicKey;
  final String? sha256;

  ContractInput({
    required this.namespace,
    required this.contract,
    required this.assetPath,
    this.baseUrl,
    this.signature,
    this.publicKey,
    this.sha256,
  });

  Map<String, dynamic> get ir => (contract['ir'] ?? contract) as Map<String, dynamic>;
}

class _Param {
  final String wire;
  final String dart;
  final TypeNode type;
  final bool optional;
  final String source;
  _Param(this.wire, this.dart, this.type, this.optional, this.source);
}

class _Endpoint {
  final Map<String, dynamic> raw;
  final String name;
  final String dartName;
  final int id;
  final String method;
  final String path;
  final List<_Param> params;
  final TypeNode returnType;
  final bool returnOptional;
  final String? streaming;
  final List<String> invalidates;
  final String? cacheIdentity;
  final bool idempotent;
  _Endpoint({
    required this.raw,
    required this.name,
    required this.dartName,
    required this.id,
    required this.method,
    required this.path,
    required this.params,
    required this.returnType,
    required this.returnOptional,
    required this.streaming,
    required this.invalidates,
    required this.cacheIdentity,
    required this.idempotent,
  });

  bool get isMutation => const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method);
  Iterable<_Param> by(String source) => params.where((p) => p.source == source);
}

/// Writes axiom_sdk.dart: default config, `AxiomSdk.create()` and one
/// module class per contract namespace.
class SdkWriter {
  final List<ContractInput> contracts;
  final Schema schema;
  final String header;
  late final TypeMapper m = TypeMapper(
    prefix: 'models.',
    enumNames: schema.mapper.enumNames,
  );

  SdkWriter({
    required this.contracts,
    required this.schema,
    required this.header,
  });

  bool _usesIdempotency = false;
  bool _usesStreams = false;
  bool _usesInvalidation = false;

  String write() {
    final body = StringBuffer();
    _writeConfig(body);
    _writeSdk(body);
    for (final c in contracts) {
      _writeModule(body, c);
    }
    _writeHelpers(body);

    final b = StringBuffer();
    b.writeln(header);
    b.writeln();
    final text = body.toString();
    final dartImports = [
      if (RegExp(r'jsonEncode|jsonDecode|utf8\.').hasMatch(text)) 'dart:convert',
      if (_usesIdempotency) 'dart:math',
      if (text.contains('Uint8List')) 'dart:typed_data',
    ];
    for (final i in dartImports) {
      b.writeln("import '$i';");
    }
    if (dartImports.isNotEmpty) b.writeln();
    b.writeln("import 'package:axiom_flutter/axiom_flutter.dart';");
    b.writeln();
    b.writeln("import 'models.dart' as models;");
    b.writeln();
    b.write(body);
    return b.toString();
  }

  // ---------------------------------------------------------------------------

  void _writeConfig(StringBuffer b) {
    final allSigned = contracts.every((c) => c.signature != null && c.publicKey != null);
    b.writeln('/// Contract configuration written by `axiom pull`.');
    b.writeln('abstract final class AxiomDefaultConfig {');
    final usesRelease = allSigned ||
        contracts.any((c) => c.sha256 != null && c.signature != null && c.publicKey != null);
    if (usesRelease) {
      b.writeln("  static const bool _release = bool.fromEnvironment('dart.vm.product');");
      b.writeln();
    }
    b.writeln('  static const AxiomConfig config = AxiomConfig(');
    b.writeln('    contracts: {');
    for (final c in contracts) {
      b.writeln('      ${GeneratorUtils.str(c.namespace)}: AxiomContractConfig(');
      if (c.baseUrl == null) {
        b.writeln('        // Neither the contract nor the pull config names a base URL;');
        b.writeln('        // override with AxiomEnvironment or --dart-define=AXIOM_BASE_URL.');
        b.writeln("        baseUrl: 'http://localhost:8000',");
      } else {
        b.writeln('        baseUrl: ${GeneratorUtils.str(c.baseUrl!)},');
      }
      b.writeln('        assetPath: ${GeneratorUtils.str(c.assetPath)},');
      if (c.signature != null) b.writeln('        signature: ${GeneratorUtils.str(c.signature!)},');
      if (c.publicKey != null) b.writeln('        publicKey: ${GeneratorUtils.str(c.publicKey!)},');
      if (c.sha256 != null && c.signature != null && c.publicKey != null) {
        b.writeln('        // Release builds use the hash-locked load.');
        b.writeln('        sha256: _release ? ${GeneratorUtils.str(c.sha256!)} : null,');
      }
      b.writeln('      ),');
    }
    b.writeln('    },');
    if (allSigned) b.writeln('    requireSignedContracts: _release,');
    b.writeln('  );');
    final hashes = contracts.where((c) => c.sha256 != null).toList();
    if (hashes.isNotEmpty) {
      b.writeln();
      b.writeln('  /// sha256 of each contract asset at generation time.');
      b.writeln('  static const Map<String, String> contractSha256 = {');
      for (final c in hashes) {
        b.writeln('    ${GeneratorUtils.str(c.namespace)}: ${GeneratorUtils.str(c.sha256!)},');
      }
      b.writeln('  };');
    }
    b.writeln('}');
    b.writeln();
  }

  void _writeSdk(StringBuffer b) {
    b.writeln('/// Entry point of the generated client.');
    b.writeln('class AxiomSdk {');
    b.write('  AxiomSdk._(this.runtime, this.initResult)');
    final inits = [
      for (final c in contracts)
        '${_prop(c)} = ${_moduleClass(c)}._(runtime, ${GeneratorUtils.str(c.namespace)})',
    ];
    if (inits.isEmpty) {
      b.writeln(';');
    } else {
      b.writeln('\n    : ${inits.join(',\n      ')};');
    }
    b.writeln();
    b.writeln('  final AxiomRuntime runtime;');
    b.writeln();
    b.writeln('  /// Outcome of runtime start-up and contract loading.');
    b.writeln('  final AxiomInitResult initResult;');
    for (final c in contracts) {
      b.writeln();
      b.writeln('  /// Endpoints of the `${c.namespace}` contract.');
      b.writeln('  final ${_moduleClass(c)} ${_prop(c)};');
    }
    b.writeln();
    b.writeln('  /// Starts the runtime and loads the contracts.');
    b.writeln('  ///');
    b.writeln('  /// Base URL priority: [baseUrlOverrides] > [environment] (or the');
    b.writeln('  /// config\'s, else `--dart-define=AXIOM_ENV` / `AXIOM_BASE_URL`) >');
    b.writeln('  /// the generated default. Throws when initialization fails.');
    b.writeln('  static Future<AxiomSdk> create({');
    b.writeln('    AxiomConfig? config,');
    b.writeln('    AxiomEnvironment? environment,');
    b.writeln('    Map<String, String>? baseUrlOverrides,');
    b.writeln('    AxiomAssetLoader? assetLoader,');
    b.writeln('  }) async {');
    b.writeln('    final base = config ?? AxiomDefaultConfig.config;');
    b.writeln('    final cfg = base.copyWith(');
    b.writeln('      environment:');
    b.writeln('          environment ?? base.environment ?? AxiomEnvironment.fromDartDefines(),');
    b.writeln('      baseUrlOverrides: baseUrlOverrides,');
    b.writeln('    );');
    b.writeln('    final runtime = AxiomRuntime();');
    b.writeln('    runtime.debug = cfg.debug;');
    if (schema.failures.isNotEmpty) {
      b.writeln('    models.ContractFailure.registerAll();');
    }
    b.writeln('    final result = await runtime.initialize(cfg, assetLoader: assetLoader);');
    b.writeln('    result.requireOk();');
    b.writeln('    return AxiomSdk._(runtime, result);');
    b.writeln('  }');
    b.writeln('}');
    b.writeln();
  }

  String _moduleClass(ContractInput c) => '${GeneratorUtils.pascalCase(c.namespace)}Module';
  String _prop(ContractInput c) => GeneratorUtils.identifier(c.namespace, avoid: {'runtime', 'initResult'});

  // ---------------------------------------------------------------------------

  List<_Endpoint> _endpoints(ContractInput c) {
    final ir = c.ir;
    final ops = <String, Map<String, dynamic>>{};
    final ui = c.contract['ui_contract_metadata'];
    if (ui is Map && ui['operations'] is List) {
      for (final op in ui['operations'] as List) {
        if (op is Map && op['endpoint'] is String) {
          ops[op['endpoint'] as String] = op.cast<String, dynamic>();
        }
      }
    }
    final raw = <Map<String, dynamic>>[];
    final node = ir['endpoints'];
    if (node is Map) {
      for (final v in node.values) {
        raw.add((v as Map).cast<String, dynamic>());
      }
    } else if (node is List) {
      for (final v in node) {
        raw.add((v as Map).cast<String, dynamic>());
      }
    }
    raw.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final used = <String>{'axiom', 'cacheIdentities', 'endpointIds', 'authMethods', 'invalidateIdentity'};
    final out = <_Endpoint>[];
    for (final ep in raw) {
      final name = ep['name'] as String;
      var dartName = GeneratorUtils.identifier(name, avoid: used);
      used.add(dartName);
      final op = ops[name] ?? const {};
      final paramAvoid = {'options', 'idempotencyKey', 'reconnect'};
      final params = <_Param>[];
      for (final p in (ep['parameters'] as List? ?? const [])) {
        final pm = (p as Map).cast<String, dynamic>();
        var dart = GeneratorUtils.identifier(pm['name'] as String, avoid: paramAvoid);
        while (params.any((x) => x.dart == dart)) {
          dart = '${dart}2';
        }
        params.add(
          _Param(
            pm['name'] as String,
            dart,
            m.resolve((pm['typeRef'] as Map? ?? const {'kind': 'json'}).cast<String, dynamic>()),
            pm['isOptional'] as bool? ?? false,
            pm['source'] as String? ?? 'query',
          ),
        );
      }
      final streaming = ep['streaming'] is Map ? (ep['streaming'] as Map)['type'] as String? : null;
      out.add(
        _Endpoint(
          raw: ep,
          name: name,
          dartName: dartName,
          id: ep['id'] as int? ?? 0,
          method: (ep['method'] as String? ?? 'GET').toUpperCase(),
          path: ep['path'] as String? ?? '/',
          params: params,
          returnType: m.resolve((ep['returnType'] as Map? ?? const {'kind': 'void'}).cast<String, dynamic>()),
          returnOptional: ep['returnIsOptional'] as bool? ?? false,
          streaming: streaming,
          invalidates: [
            ...{
              ...(ep['invalidates'] as List? ?? const []).cast<String>(),
              ...(op['invalidates'] as List? ?? const []).cast<String>(),
            },
          ]..sort(),
          cacheIdentity: (ep['cacheIdentity'] ?? op['cacheIdentity']) as String?,
          idempotent: op['idempotent'] == true,
        ),
      );
    }
    return out;
  }

  void _writeModule(StringBuffer b, ContractInput c) {
    final cls = _moduleClass(c);
    final endpoints = _endpoints(c);
    final project = c.contract['project'];
    final ident = project is Map
        ? ' (${project['project_id'] ?? ''} ${project['version'] ?? ''})'.replaceAll(' )', ')')
        : '';

    // Cache identity -> endpoint ids (deterministic).
    // Skip the compiler's synthetic `endpoint:<id>` identities unless a
    // mutation names them.
    final referenced = {for (final e in endpoints) ...e.invalidates};
    final identities = <String, List<int>>{};
    for (final e in endpoints) {
      final id = e.cacheIdentity;
      if (id == null) continue;
      if (id.startsWith('endpoint:') && !referenced.contains(id)) continue;
      identities.putIfAbsent(id, () => []).add(e.id);
    }
    final authMethods = <String>{};
    for (final e in endpoints) {
      final auth = e.raw['auth'];
      if (auth is Map && auth['methods'] is List) {
        for (final am in auth['methods'] as List) {
          if (am is Map && am['name'] is String) authMethods.add(am['name'] as String);
        }
      }
    }

    b.writeln('/// Client for the `${c.namespace}` contract$ident.');
    b.writeln('class $cls {');
    b.writeln('  $cls._(this._runtime, this._namespace)');
    b.writeln('    : axiom = ${cls}AxiomNamespace._(_runtime, _namespace);');
    b.writeln();
    b.writeln('  final AxiomRuntime _runtime;');
    b.writeln('  final String _namespace;');
    b.writeln();
    b.writeln('  /// Auth tokens and cache control for this namespace.');
    b.writeln('  final ${cls}AxiomNamespace axiom;');
    b.writeln();
    b.writeln('  /// Endpoint ids by contract endpoint name.');
    b.writeln('  static const Map<String, int> endpointIds = {');
    for (final e in endpoints) {
      b.writeln('    ${GeneratorUtils.str(e.name)}: ${e.id},');
    }
    b.writeln('  };');
    b.writeln();
    b.writeln('  /// Endpoint ids by contract cache identity.');
    b.writeln('  static const Map<String, List<int>> cacheIdentities = {');
    for (final k in identities.keys.toList()..sort()) {
      b.writeln('    ${GeneratorUtils.str(k)}: [${(identities[k]!..sort()).join(', ')}],');
    }
    b.writeln('  };');
    b.writeln();
    b.writeln('  /// Auth method names declared by the contract.');
    b.writeln('  static const List<String> authMethods = [');
    for (final a in authMethods.toList()..sort()) {
      b.writeln('    ${GeneratorUtils.str(a)},');
    }
    b.writeln('  ];');

    for (final e in endpoints) {
      b.writeln();
      _writeEndpoint(b, e, identities);
      if (e.streaming == 'sse' || e.streaming == 'http_stream') {
        b.writeln();
        _writeStreamHelper(b, e);
      } else if (e.streaming == 'websocket') {
        b.writeln();
        _writeChannel(b, e);
      }
    }
    b.writeln();
    b.writeln('  /// Refetches the active queries of every endpoint with [identity].');
    b.writeln('  void invalidateIdentity(String identity) {');
    b.writeln('    final ids = cacheIdentities[identity];');
    b.writeln('    if (ids == null) return;');
    b.writeln('    _invalidateEndpoints(_runtime, _namespace, ids);');
    b.writeln('  }');
    _usesInvalidation = true;
    b.writeln('}');
    b.writeln();

    // Namespace helper.
    b.writeln('/// Namespace-level runtime controls for `${c.namespace}`.');
    b.writeln('class ${cls}AxiomNamespace {');
    b.writeln('  ${cls}AxiomNamespace._(this._runtime, this._namespace);');
    b.writeln();
    b.writeln('  final AxiomRuntime _runtime;');
    b.writeln('  final String _namespace;');
    b.writeln();
    b.writeln('  void setAuthToken(String methodName, String token) {');
    b.writeln('    _runtime.setAuthToken(namespace: _namespace, methodName: methodName, token: token);');
    b.writeln('  }');
    b.writeln();
    b.writeln('  void clearAuthToken(String methodName) {');
    b.writeln('    _runtime.clearAuthToken(namespace: _namespace, methodName: methodName);');
    b.writeln('  }');
    b.writeln();
    b.writeln('  /// Sets [token] for every auth method of this namespace.');
    b.writeln('  void setNamespaceToken(String token) {');
    b.writeln('    _runtime.setNamespaceAuthToken(namespace: _namespace, token: token);');
    b.writeln('  }');
    b.writeln();
    b.writeln('  void clearNamespaceToken() {');
    b.writeln('    _runtime.clearNamespaceAuthToken(namespace: _namespace);');
    b.writeln('  }');
    b.writeln();
    b.writeln('  /// Marks every cached query of this namespace stale and refetches.');
    b.writeln('  void invalidateAll() {');
    b.writeln('    _runtime.invalidate(namespace: _namespace);');
    b.writeln('  }');
    b.writeln('}');
    b.writeln();
  }

  // ---------------------------------------------------------------------------

  String _signature(_Endpoint e, {bool includeBody = true, List<String> extra = const []}) {
    final parts = <String>[];
    for (final p in e.params) {
      if (!includeBody && p.source == 'body') continue;
      final t = m.dartType(p.type);
      if (p.optional) {
        parts.add('${t.endsWith('?') ? t : '$t?'} ${p.dart}');
      } else {
        parts.add('required $t ${p.dart}');
      }
    }
    parts.addAll(extra);
    if (parts.isEmpty) return '';
    return '{\n    ${parts.join(',\n    ')},\n  }';
  }

  String _returnType(_Endpoint e) {
    final t = m.dartType(e.returnType);
    if (e.returnOptional && !t.endsWith('?') && t != 'void') return '$t?';
    return t;
  }

  String _decoder(_Endpoint e) {
    final t = e.returnType;
    if (t is VoidType) return '${m.codec}.asVoid';
    if (e.returnOptional) return '(json) => ${m.decodeNullable(t, 'json')}';
    if (t is JsonType) return '${m.codec}.asJson';
    if (t is ListType || t is MapType) return '(json) => ${m.decode(t, 'json')}';
    return m.decodeFn(t);
  }

  /// Writes `final headers = ...;` etc. and returns the named arguments.
  List<String> _requestParts(
    StringBuffer b,
    _Endpoint e, {
    bool includeBody = true,
    bool idempotency = false,
  }) {
    final args = <String>[];
    final headers = e.by('header').toList();
    if (headers.isNotEmpty || idempotency) {
      b.writeln('    final headers = <String, String>{');
      for (final p in headers) {
        final v = m.toParamString(p.type, p.optional ? 'v' : p.dart);
        b.writeln(
          p.optional
              ? '      if (${p.dart} case final v?) ${GeneratorUtils.str(p.wire)}: $v,'
              : '      ${GeneratorUtils.str(p.wire)}: $v,',
        );
      }
      if (idempotency) {
        b.writeln(
          e.idempotent
              ? "      'Idempotency-Key': idempotencyKey ?? _newIdempotencyKey(),"
              : "      if (idempotencyKey case final k?) 'Idempotency-Key': k,",
        );
      }
      b.writeln('    };');
      args.add('headers: options?.mergeHeaders(headers) ?? headers');
    } else {
      args.add('headers: options?.mergeHeaders(null)');
    }
    final path = e.by('path').toList();
    if (path.isNotEmpty) {
      final entries = [
        for (final p in path)
          p.optional
              ? 'if (${p.dart} case final v?) ${GeneratorUtils.str(p.wire)}: Uri.encodeComponent(${m.toParamString(p.type, 'v')})'
              : '${GeneratorUtils.str(p.wire)}: Uri.encodeComponent(${m.toParamString(p.type, p.dart)})',
      ];
      args.add('pathParams: {${entries.join(', ')}}');
    }
    final query = e.by('query').toList();
    if (query.isNotEmpty) {
      final entries = [
        for (final p in query)
          p.optional
              ? 'if (${p.dart} case final v?) ${GeneratorUtils.str(p.wire)}: ${m.toParamString(p.type, 'v')}'
              : '${GeneratorUtils.str(p.wire)}: ${m.toParamString(p.type, p.dart)}',
      ];
      args.add('queryParams: {${entries.join(', ')}}');
    }
    if (includeBody) {
      final body = e.by('body').toList();
      if (body.length == 1) {
        final p = body.single;
        args.add(
          p.optional
              ? 'body: ${p.dart} == null ? null : jsonEncode(${m.encode(p.type, '${p.dart}!')})'
              : 'body: jsonEncode(${m.encode(p.type, p.dart)})',
        );
      } else if (body.length > 1) {
        final entries = [
          for (final p in body)
            p.optional
                ? 'if (${p.dart} case final v?) ${GeneratorUtils.str(p.wire)}: ${m.encode(p.type, 'v')}'
                : '${GeneratorUtils.str(p.wire)}: ${m.encode(p.type, p.dart)}',
        ];
        args.add('body: jsonEncode(<String, dynamic>{${entries.join(', ')}})');
      }
    }
    return args;
  }

  String _argsMap(_Endpoint e) {
    final entries = [
      for (final p in e.params)
        p.optional
            ? 'if (${p.dart} case final v?) ${GeneratorUtils.str(p.wire)}: ${m.encode(p.type, 'v')}'
            : '${GeneratorUtils.str(p.wire)}: ${m.encode(p.type, p.dart)}',
    ];
    return '<String, dynamic>{${entries.join(', ')}}';
  }

  void _writeDoc(StringBuffer b, _Endpoint e) {
    b.write(GeneratorUtils.docComment(e.raw['doc'] as String?, '  '));
    b.writeln('  /// `${e.method} ${e.path}`${e.streaming != null ? ' (${e.streaming})' : ''}.');
    final cache = e.raw['cache'];
    if (cache is Map && cache['strategy'] != null) {
      b.writeln('  ///');
      b.writeln(
        '  /// Cache: `${cache['strategy']}`${cache['ttlSeconds'] != null ? ', ttl ${cache['ttlSeconds']}s' : ''}. '
        'Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.',
      );
    }
    if (e.cacheIdentity != null && !e.cacheIdentity!.startsWith('endpoint:')) {
      b.writeln('  ///');
      b.writeln('  /// Cache identity: `${e.cacheIdentity}`.');
    }
    if (e.invalidates.isNotEmpty) {
      b.writeln('  ///');
      b.writeln('  /// On success invalidates: ${e.invalidates.map((i) => '`$i`').join(', ')}.');
    }
    final failures = schema.endpointFailures[e.name];
    if (failures != null && failures.isNotEmpty) {
      b.writeln('  ///');
      b.writeln(
        '  /// Typed failures: ${failures.map((f) => '[models.${schema.failures[f]!.dartName}]').join(', ')}; '
        'match with `error.when${GeneratorUtils.pascalCase(e.name)}(...)`.',
      );
    }
  }

  void _writeEndpoint(StringBuffer b, _Endpoint e, Map<String, List<int>> identities) {
    final rt = _returnType(e);
    final idem = e.isMutation;
    if (idem && e.idempotent) _usesIdempotency = true;
    final extra = [
      if (idem) 'String? idempotencyKey',
      'AxiomCallOptions? options',
    ];
    _writeDoc(b, e);
    b.writeln('  AxiomQuery<$rt> ${e.dartName}(${_signature(e, extra: extra)}) {');
    final parts = _requestParts(b, e, idempotency: idem);
    final call = e.isMutation ? 'sendMutation' : 'send';
    final invalidated = <int>{
      for (final i in e.invalidates) ...?identities[i],
    }.toList()
      ..sort();
    final prefix = invalidated.isEmpty ? 'return' : 'final query =';
    b.writeln('    $prefix _runtime.$call<$rt>(');
    b.writeln('      namespace: _namespace,');
    b.writeln('      endpointId: ${e.id},');
    b.writeln('      method: ${GeneratorUtils.str(e.method)},');
    b.writeln('      path: ${GeneratorUtils.str(e.path)},');
    for (final p in parts) {
      b.writeln('      $p,');
    }
    b.writeln('      args: ${_argsMap(e)},');
    b.writeln('      decoder: ${_decoder(e)},');
    b.writeln('      options: options,');
    b.writeln('    );');
    if (invalidated.isNotEmpty) {
      _usesInvalidation = true;
      b.writeln('    return _onSuccess(query, _runtime, () {');
      b.writeln('      _invalidateEndpoints(_runtime, _namespace, const [${invalidated.join(', ')}]);');
      b.writeln('    });');
    }
    b.writeln('  }');
  }

  void _writeStreamHelper(StringBuffer b, _Endpoint e) {
    _usesStreams = true;
    final rt = m.dartType(e.returnType);
    b.writeln('  /// Frames of `${e.name}` as a typed stream. Cancelling the subscription');
    b.writeln('  /// cancels the request.');
    b.writeln('  Stream<$rt> ${e.dartName}Stream(${_signature(e, extra: ['AxiomCallOptions? options'])}) {');
    final parts = _requestParts(b, e);
    final bodyIdx = parts.indexWhere((p) => p.startsWith('body: '));
    String? body;
    if (bodyIdx >= 0) body = parts.removeAt(bodyIdx).substring('body: '.length);
    b.writeln('    final response = _runtime.callStream(');
    b.writeln('      namespace: _namespace,');
    b.writeln('      endpointId: ${e.id},');
    b.writeln('      method: ${GeneratorUtils.str(e.method)},');
    b.writeln('      path: ${GeneratorUtils.str(e.path)},');
    for (final p in parts) {
      b.writeln('      $p,');
    }
    b.writeln(
      body == null
          ? '      requestBytes: Uint8List(0),'
          : '      requestBytes: _utf8Bytes($body),',
    );
    b.writeln('      options: options,');
    b.writeln('    );');
    b.writeln('    return _frames(response, _runtime, ${m.decodeFn(e.returnType)});');
    b.writeln('  }');
  }

  void _writeChannel(StringBuffer b, _Endpoint e) {
    final s = e.raw['streaming'] as Map;
    TypeNode? msg(String side) {
      final d = s[side];
      if (d is Map && d['model'] is Map) {
        return m.resolve((d['model'] as Map).cast<String, dynamic>());
      }
      return null;
    }

    final bodyParams = e.by('body').toList();
    final receive = msg('server') ?? e.returnType;
    final send = msg('client') ??
        (bodyParams.length == 1 ? bodyParams.single.type : const JsonType());
    final rt = m.dartType(receive);
    final st = m.dartType(send);
    final auto = s['reconnect'] == 'auto';
    b.writeln('  /// Typed WebSocket channel for `${e.name}`: send [$st], receive [$rt].');
    b.writeln('  AxiomChannel<$rt, $st> ${e.dartName}Channel(${_signature(e, includeBody: false, extra: [
      'AxiomReconnectPolicy reconnect = AxiomReconnectPolicy.${auto ? 'auto' : 'none'}',
      'AxiomCallOptions? options',
    ])}) {');
    final parts = _requestParts(b, e, includeBody: false);
    b.writeln('    return _runtime.openChannel<$rt, $st>(');
    b.writeln('      namespace: _namespace,');
    b.writeln('      endpointId: ${e.id},');
    b.writeln('      method: ${GeneratorUtils.str(e.method)},');
    b.writeln('      path: ${GeneratorUtils.str(e.path)},');
    for (final p in parts) {
      b.writeln('      $p,');
    }
    b.writeln('      decoder: ${receive is JsonType ? '${m.codec}.asJson' : m.decodeFn(receive)},');
    b.writeln('      reconnect: reconnect,');
    b.writeln('      options: options,');
    b.writeln('    );');
    b.writeln('  }');
  }

  // ---------------------------------------------------------------------------

  void _writeHelpers(StringBuffer b) {
    final text = b.toString();
    bool uses(String name) => text.contains('$name(');
    if (_usesInvalidation && uses('_invalidateEndpoints')) {
      b.write(r'''
/// Refetches active queries of [endpointIds] after a mutation (the runtime
/// already dropped their cached responses).
void _invalidateEndpoints(
  AxiomRuntime runtime,
  String namespace,
  List<int> endpointIds,
) {
  for (final id in endpointIds) {
    try {
      runtime.invalidate(namespace: namespace, endpointId: id);
    } on UnimplementedError {
      return;
    }
  }
}

''');
    }
    if (uses('_onSuccess')) {
      b.write(r'''
/// Wraps a mutation so [onSuccess] runs once after its first success.
AxiomQuery<T> _onSuccess<T>(
  AxiomQuery<T> query,
  AxiomRuntime runtime,
  void Function() onSuccess,
) {
  var done = false;
  return AxiomQuery<T>(
    query.key,
    (headers) {
      headers.forEach(query.setHeader);
      final stream = query.stream.map((state) {
        if (!done && state.status == AxiomStatus.success) {
          done = true;
          onSuccess();
        }
        return state;
      });
      return AxiomActiveStream<T>(query.requestId ?? 0, stream);
    },
    isMutation: true,
    runtime: runtime,
  );
}

''');
    }
    if (_usesIdempotency) {
      b.write(r'''
final Random _random = Random.secure();

String _newIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

''');
    }
    if (uses('_utf8Bytes')) {
      b.write(r'''
Uint8List _utf8Bytes(String? text) =>
    text == null ? Uint8List(0) : Uint8List.fromList(utf8.encode(text));
''');
    }
    if (_usesStreams) {
      b.write(r'''

/// Decodes stream chunks (JSON, NDJSON or SSE `data:` lines) into frames.
Stream<T> _frames<T>(
  AxiomStreamResponse response,
  AxiomRuntime runtime,
  T Function(Object?) decode,
) async* {
  var finished = false;
  try {
    await for (final state in response.stream) {
      final error = state.error;
      if (error != null) {
        finished = true;
        if (error.isCancelled) return;
        throw error;
      }
      final data = state.data;
      if (data != null && data.isNotEmpty) {
        for (final frame in _splitFrames(utf8.decode(data))) {
          yield decode(frame);
        }
      }
    }
    finished = true;
  } finally {
    if (!finished) {
      try {
        runtime.cancel(response.requestId);
      } on UnimplementedError {
        // Runtime without cancel support.
      }
    }
  }
}

List<Object?> _splitFrames(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (!trimmed.startsWith('data:') && !trimmed.startsWith('event:') &&
      !trimmed.startsWith('id:') && !trimmed.startsWith(':')) {
    try {
      return [jsonDecode(trimmed)];
    } on FormatException {
      return [
        for (final line in trimmed.split('\n'))
          if (line.trim().isNotEmpty) jsonDecode(line),
      ];
    }
  }
  final frames = <Object?>[];
  final data = <String>[];
  for (final line in '$trimmed\n\n'.split('\n')) {
    if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    } else if (line.trim().isEmpty && data.isNotEmpty) {
      frames.add(jsonDecode(data.join('\n')));
      data.clear();
    }
  }
  return frames;
}
''');
    }
  }
}
