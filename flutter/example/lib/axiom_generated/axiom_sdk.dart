// GENERATED CODE – DO NOT EDIT.
// ignore_for_file: unused_import
// ignore_for_file: invalid_null_aware_operator

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:example/axiom_generated/models.dart' as models;

class AxiomSdk {
  final AxiomRuntime _runtime;
  late final UsersModule users;

  AxiomSdk._(this._runtime) {
    users = UsersModule(_runtime);
  }

  static Future<AxiomSdk> create(AxiomConfig config) async {
    WidgetsFlutterBinding.ensureInitialized();
    final runtime = AxiomRuntime();
    runtime.debug = config.debug;
    await runtime.init(config.dbPath);

    for (final entry in config.contracts.entries) {
      final c = entry.value;
      final contractData = await rootBundle.load(c.assetPath);
      final contractBytes = contractData.buffer.asUint8List();

      runtime.loadContract(
        namespace: entry.key,
        baseUrl: c.baseUrl,
        contractBytes: contractBytes,
        signature: null,
        publicKey: null,
      );
    }
    return AxiomSdk._(runtime);
  }

}

class UsersModule {
  final AxiomRuntime _runtime;

  UsersModule(this._runtime);

  AxiomQuery<models.User> getUser({required int userId, }) {
      final argsMap = <String, dynamic>{
        'user_id': userId,
      };
      final pathParams = <String, dynamic>{
        'user_id': userId,
      };
      return _runtime.send<models.User>(
        namespace: 'users',
        endpointId: 0,
        method: 'GET',
        path: '/users/{user_id}',
        args: argsMap,
        pathParams: pathParams,
        decoder: (json) => models.User.fromJson(json),
      );
  }

  AxiomMutation<models.User, ({models.User user})> createUser() {
    return AxiomMutation((args) {
      final argsMap = <String, dynamic>{
        'user': args.user?.toJson(),
      };
      return _runtime.send<models.User>(
        namespace: 'users',
        endpointId: 1,
        method: 'POST',
        path: '/users',
        args: argsMap,
        body: args.user,
        decoder: (json) => models.User.fromJson(json),
      );
    });
  }

}
