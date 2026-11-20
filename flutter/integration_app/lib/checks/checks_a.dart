// Unit a: Android packaging checks. They SKIP on every other platform.
import 'package:flutter/foundation.dart';

import 'checks_a_stub.dart' if (dart.library.io) 'checks_a_io.dart' as plat;
import 'ctx.dart';

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final androidChecks = <CheckDef>[
  CheckDef('android.library_loaded', 'android', (c) async {
    if (!_isAndroid) skip('android only');
    // Reaching here means DynamicLibrary.open('libaxiom_runtime.so') worked
    // during init; a network round trip proves the FFI calls work too.
    final r = await data(c.api.echo(path: 'android', q: 'jni', limit: 1));
    expectEq(r.q, 'jni', 'echo');
  }),
  CheckDef('android.default_cache_dir', 'android', (c) async {
    if (!_isAndroid) skip('android only');
    // init() without dbPath must put the sled cache under the app support dir.
    final found = await plat.findSledCache();
    expectThat(found != null, 'no axiom_cache.sled under <app support>/axiom');
  }),
];
