// GENERATED CODE – DO NOT EDIT.
// ignore_for_file: unused_import
// ignore_for_file: invalid_null_aware_operator

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter/src/internal/query_key.dart';
import 'package:axiom_flutter/src/internal/axiom_codec.dart';
import 'package:axiom_flutter/src/query_manager.dart';
import 'package:axiom_fixture_app/axiom_generated/models.dart' as models;

class AxiomDefaultConfig {
  static AxiomConfig get config => const AxiomConfig(
    contracts: {
      'fixture': AxiomContractConfig(
        baseUrl: 'http://localhost:8000',
        assetPath: 'assets/axiom/fixture.axiom',
      ),
    },
  );
}

class AxiomSdk {
  final AxiomRuntime runtime;

  late final FixtureModule fixture;

  AxiomSdk._(this.runtime) {
    fixture = FixtureModule(runtime, 'fixture');
  }

  static Future<AxiomSdk> create({AxiomConfig? config}) async {
    WidgetsFlutterBinding.ensureInitialized();
    final runtime = AxiomRuntime();
    final cfg = config ?? AxiomDefaultConfig.config;
    runtime.debug = cfg.debug;
    await runtime.init(cfg.dbPath);

    for (final entry in cfg.contracts.entries) {
      final c = entry.value;
      final contractData = await rootBundle.load(c.assetPath);
      final contractBytes = contractData.buffer.asUint8List();
      runtime.loadContract(
        namespace: entry.key,
        baseUrl: c.baseUrl,
        contractBytes: contractBytes,
      );
    }
    return AxiomSdk._(runtime);
  }
}

class FixtureModule {
  final AxiomRuntime _runtime;
  final String _namespace;
  late final FixtureModuleAxiomNamespace axiom;

  FixtureModule(this._runtime, this._namespace) {
    axiom = FixtureModuleAxiomNamespace(this);
  }

  AxiomQuery<models.Who> authApiKeyHeader({required String xApiKey}) {
    final argsMap = <String, dynamic>{'x-api-key': xApiKey};
    return _runtime.send<models.Who>(
      namespace: _namespace,
      endpointId: 1256260924,
      method: 'GET',
      path: '/auth/api-key-header',
      args: argsMap,
      decoder: (json) => models.Who.fromJson(json),
    );
  }

  AxiomQuery<models.Who> authApiKeyQuery({required String apiKey}) {
    final argsMap = <String, dynamic>{'api_key': apiKey};
    final queryParams = <String, dynamic>{'api_key': apiKey};
    return _runtime.send<models.Who>(
      namespace: _namespace,
      endpointId: 2900873362,
      method: 'GET',
      path: '/auth/api-key-query',
      args: argsMap,
      queryParams: queryParams,
      decoder: (json) => models.Who.fromJson(json),
    );
  }

  AxiomQuery<models.Who> authBearer() {
    final argsMap = <String, dynamic>{};
    return _runtime.send<models.Who>(
      namespace: _namespace,
      endpointId: 1404635741,
      method: 'GET',
      path: '/auth/bearer',
      args: argsMap,
      decoder: (json) => models.Who.fromJson(json),
    );
  }

  AxiomQuery<models.Stamp> cacheCacheFirst({required String xFixtureNonce}) {
    final argsMap = <String, dynamic>{'x-fixture-nonce': xFixtureNonce};
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 3177318534,
      method: 'GET',
      path: '/cache/cache-first',
      args: argsMap,
      decoder: (json) => models.Stamp.fromJson(json),
    );
  }

  AxiomQuery<models.Stamp> cacheNetworkFirst({required String xFixtureNonce}) {
    final argsMap = <String, dynamic>{'x-fixture-nonce': xFixtureNonce};
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 1010416358,
      method: 'GET',
      path: '/cache/network-first',
      args: argsMap,
      decoder: (json) => models.Stamp.fromJson(json),
    );
  }

  AxiomQuery<models.Stamp> cacheNetworkOnly({required String xFixtureNonce}) {
    final argsMap = <String, dynamic>{'x-fixture-nonce': xFixtureNonce};
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 837292962,
      method: 'GET',
      path: '/cache/network-only',
      args: argsMap,
      decoder: (json) => models.Stamp.fromJson(json),
    );
  }

  AxiomQuery<models.Stamp> cacheStale({required String xFixtureNonce}) {
    final argsMap = <String, dynamic>{'x-fixture-nonce': xFixtureNonce};
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 929374064,
      method: 'GET',
      path: '/cache/stale-while-revalidate',
      args: argsMap,
      decoder: (json) => models.Stamp.fromJson(json),
    );
  }

  AxiomQuery<models.Stamp> cachedItem({
    required String id,
    required String xFixtureNonce,
  }) {
    final argsMap = <String, dynamic>{
      'id': id,
      'x-fixture-nonce': xFixtureNonce,
    };
    final pathParams = <String, dynamic>{'id': id};
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 1498157384,
      method: 'GET',
      path: '/cache/items/{id}',
      args: argsMap,
      pathParams: pathParams,
      decoder: (json) => models.Stamp.fromJson(json),
    );
  }

  AxiomQuery<models.Tick> chunked({String? last}) {
    final argsMap = <String, dynamic>{'last': last};
    final queryParams = <String, dynamic>{'last': last};
    return _runtime.send<models.Tick>(
      namespace: _namespace,
      endpointId: 4017861805,
      method: 'GET',
      path: '/stream/chunked',
      args: argsMap,
      queryParams: queryParams,
      decoder: (json) => models.Tick.fromJson(json),
    );
  }

  AxiomQuery<models.Item> claim({required String name}) {
    final argsMap = <String, dynamic>{'name': name};
    return _runtime.sendMutation<models.Item>(
      namespace: _namespace,
      endpointId: 3649530469,
      method: 'POST',
      path: '/claims',
      args: argsMap,
      body: name,
      decoder: (json) => models.Item.fromJson(json),
    );
  }

  AxiomQuery<models.Item> createItem({required String name, required int qty}) {
    final argsMap = <String, dynamic>{'name': name, 'qty': qty};
    return _runtime.sendMutation<models.Item>(
      namespace: _namespace,
      endpointId: 631501414,
      method: 'POST',
      path: '/items',
      args: argsMap,
      body: qty,
      decoder: (json) => models.Item.fromJson(json),
    );
  }

  AxiomQuery<models.Deleted> deleteItem({
    required String id,
    Map<String, dynamic>? body,
  }) {
    final argsMap = <String, dynamic>{'id': id};
    final pathParams = <String, dynamic>{'id': id};
    return _runtime.sendMutation<models.Deleted>(
      namespace: _namespace,
      endpointId: 3209564247,
      method: 'DELETE',
      path: '/items/{id}',
      args: argsMap,
      pathParams: pathParams,
      body: body,
      decoder: (json) => models.Deleted.fromJson(json),
    );
  }

  AxiomQuery<models.Echo> echo({
    required String path,
    required String q,
    required int limit,
    bool? flag,
  }) {
    final argsMap = <String, dynamic>{
      'path': path,
      'q': q,
      'limit': limit,
      'flag': flag,
    };
    final pathParams = <String, dynamic>{'path': path};
    final queryParams = <String, dynamic>{'q': q, 'limit': limit, 'flag': flag};
    return _runtime.send<models.Echo>(
      namespace: _namespace,
      endpointId: 1421147111,
      method: 'GET',
      path: '/echo/{path}',
      args: argsMap,
      pathParams: pathParams,
      queryParams: queryParams,
      decoder: (json) => models.Echo.fromJson(json),
    );
  }

  AxiomQuery<models.Everything> everything() {
    final argsMap = <String, dynamic>{};
    return _runtime.send<models.Everything>(
      namespace: _namespace,
      endpointId: 1643923642,
      method: 'GET',
      path: '/types/everything',
      args: argsMap,
      decoder: (json) => models.Everything.fromJson(json),
    );
  }

  AxiomQuery<models.Retried> retried({required int attempt}) {
    final argsMap = <String, dynamic>{'attempt': attempt};
    final queryParams = <String, dynamic>{'attempt': attempt};
    return _runtime.send<models.Retried>(
      namespace: _namespace,
      endpointId: 2446114110,
      method: 'GET',
      path: '/retry',
      args: argsMap,
      queryParams: queryParams,
      decoder: (json) => models.Retried.fromJson(json),
    );
  }

  AxiomQuery<models.Tick> sse({String? lastEventId}) {
    final argsMap = <String, dynamic>{'last-event-id': lastEventId};
    return _runtime.send<models.Tick>(
      namespace: _namespace,
      endpointId: 78174837,
      method: 'GET',
      path: '/stream/sse',
      args: argsMap,
      decoder: (json) => models.Tick.fromJson(json),
    );
  }

  AxiomQuery<models.Stamp> touchItem({
    required String id,
    required String xFixtureNonce,
    Map<String, dynamic>? body,
  }) {
    final argsMap = <String, dynamic>{
      'id': id,
      'x-fixture-nonce': xFixtureNonce,
    };
    final pathParams = <String, dynamic>{'id': id};
    return _runtime.sendMutation<models.Stamp>(
      namespace: _namespace,
      endpointId: 4036857016,
      method: 'POST',
      path: '/cache/items/{id}/touch',
      args: argsMap,
      pathParams: pathParams,
      body: body,
      decoder: (json) => models.Stamp.fromJson(json),
    );
  }

  AxiomQuery<models.Item> updateItem({
    required String id,
    required String name,
    required int qty,
  }) {
    final argsMap = <String, dynamic>{'id': id, 'name': name, 'qty': qty};
    final pathParams = <String, dynamic>{'id': id};
    return _runtime.sendMutation<models.Item>(
      namespace: _namespace,
      endpointId: 3182762126,
      method: 'PUT',
      path: '/items/{id}',
      args: argsMap,
      pathParams: pathParams,
      body: qty,
      decoder: (json) => models.Item.fromJson(json),
    );
  }

  AxiomQuery<models.BytesOut> uploadBytes({required Uint8List data}) {
    final argsMap = <String, dynamic>{'data': data};
    return _runtime.sendMutation<models.BytesOut>(
      namespace: _namespace,
      endpointId: 1096035656,
      method: 'POST',
      path: '/bytes',
      args: argsMap,
      body: data,
      decoder: (json) => models.BytesOut.fromJson(json),
    );
  }

  AxiomQuery<models.Ping> wsEcho({required models.Ping message}) {
    final argsMap = <String, dynamic>{'message': message.toJson()};
    return _runtime.send<models.Ping>(
      namespace: _namespace,
      endpointId: 1471516720,
      method: 'WS',
      path: '/stream/ws',
      args: argsMap,
      body: message,
      decoder: (json) => models.Ping.fromJson(json),
    );
  }
}

class FixtureModuleAxiomNamespace {
  final FixtureModule _parent;
  FixtureModuleAxiomNamespace(this._parent);

  void setAuthToken(String methodName, String token) {
    _parent._runtime.setAuthToken(
      namespace: _parent._namespace,
      methodName: methodName,
      token: token,
    );
  }

  void clearAuthToken(String methodName) {
    _parent._runtime.clearAuthToken(
      namespace: _parent._namespace,
      methodName: methodName,
    );
  }

  void connect(String methodName, {Map<String, dynamic> args = const {}}) {
    print(
      'Warning: .connect() in Dart requires active UI subscription. Use the endpoint stream directly.',
    );
  }

  void disconnect(String methodName, {Map<String, dynamic> args = const {}}) {
    int? endpointId;
    switch (methodName) {
      case 'authApiKeyHeader':
        endpointId = 1256260924;
        break;
      case 'authApiKeyQuery':
        endpointId = 2900873362;
        break;
      case 'authBearer':
        endpointId = 1404635741;
        break;
      case 'cacheCacheFirst':
        endpointId = 3177318534;
        break;
      case 'cacheNetworkFirst':
        endpointId = 1010416358;
        break;
      case 'cacheNetworkOnly':
        endpointId = 837292962;
        break;
      case 'cacheStale':
        endpointId = 929374064;
        break;
      case 'cachedItem':
        endpointId = 1498157384;
        break;
      case 'chunked':
        endpointId = 4017861805;
        break;
      case 'claim':
        endpointId = 3649530469;
        break;
      case 'createItem':
        endpointId = 631501414;
        break;
      case 'deleteItem':
        endpointId = 3209564247;
        break;
      case 'echo':
        endpointId = 1421147111;
        break;
      case 'everything':
        endpointId = 1643923642;
        break;
      case 'retried':
        endpointId = 2446114110;
        break;
      case 'sse':
        endpointId = 78174837;
        break;
      case 'touchItem':
        endpointId = 4036857016;
        break;
      case 'updateItem':
        endpointId = 3182762126;
        break;
      case 'uploadBytes':
        endpointId = 1096035656;
        break;
      case 'wsEcho':
        endpointId = 1471516720;
        break;
    }
    if (endpointId != null) {
      final key = AxiomQueryKey.build(
        endpoint: '${_parent._namespace}_$endpointId',
        args: args,
      );
      AxiomQueryManager().remove(key);
    }
  }

  void send(
    String methodName,
    dynamic payload, {
    Map<String, dynamic> args = const {},
  }) {
    int? endpointId;
    switch (methodName) {
      case 'authApiKeyHeader':
        endpointId = 1256260924;
        break;
      case 'authApiKeyQuery':
        endpointId = 2900873362;
        break;
      case 'authBearer':
        endpointId = 1404635741;
        break;
      case 'cacheCacheFirst':
        endpointId = 3177318534;
        break;
      case 'cacheNetworkFirst':
        endpointId = 1010416358;
        break;
      case 'cacheNetworkOnly':
        endpointId = 837292962;
        break;
      case 'cacheStale':
        endpointId = 929374064;
        break;
      case 'cachedItem':
        endpointId = 1498157384;
        break;
      case 'chunked':
        endpointId = 4017861805;
        break;
      case 'claim':
        endpointId = 3649530469;
        break;
      case 'createItem':
        endpointId = 631501414;
        break;
      case 'deleteItem':
        endpointId = 3209564247;
        break;
      case 'echo':
        endpointId = 1421147111;
        break;
      case 'everything':
        endpointId = 1643923642;
        break;
      case 'retried':
        endpointId = 2446114110;
        break;
      case 'sse':
        endpointId = 78174837;
        break;
      case 'touchItem':
        endpointId = 4036857016;
        break;
      case 'updateItem':
        endpointId = 3182762126;
        break;
      case 'uploadBytes':
        endpointId = 1096035656;
        break;
      case 'wsEcho':
        endpointId = 1471516720;
        break;
    }
    if (endpointId == null) return;
    final key = AxiomQueryKey.build(
      endpoint: '${_parent._namespace}_$endpointId',
      args: args,
    );
    final bytes = AxiomCodec.encodeBody(payload, null);
    AxiomQueryManager().send(key, bytes, _parent._runtime);
  }
}
